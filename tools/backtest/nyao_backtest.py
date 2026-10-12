#!/usr/bin/env python3
"""Automated MetaTrader 5 Strategy Tester runs for Nyao Scalper, with a generated report.

  python tools/backtest/nyao_backtest.py run --name default-2026 --periods M1,M5 --from 2026-01 --to 2026-09
  python tools/backtest/nyao_backtest.py report --name default-2026

`run` compiles the EA from this repo into the terminal (MQL5/Experts/NyaoBacktest), installs the .set file,
closes the terminal, runs one Strategy Tester pass per timeframe x month (fresh deposit each), reopens the
terminal and writes reports/<name>/ (summary.md, index.html, results.csv, graphs/). `report` rebuilds that
folder from the terminal's existing tester reports. Windows only; Python 3.8+ standard library only.
"""
import argparse
import csv
import ctypes
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from ctypes import wintypes
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EXPERT_SUBDIR = 'NyaoBacktest'
TERMINAL_CANDIDATES = [r'C:\Program Files\MetaTrader 5\terminal64.exe']
MODELS = {'every': 0, 'ohlc': 1, 'open': 2, 'real': 4}
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000


# --------------------------------------------------------------------------- terminal / files

def find_terminal(path):
    for p in ([path] if path else TERMINAL_CANDIDATES):
        if p and Path(p).is_file():
            return Path(p)
    sys.exit('terminal64.exe not found - pass --terminal "C:\\...\\terminal64.exe"')


def find_data_dir(terminal, override):
    if override:
        return Path(override)
    root = Path(os.environ['APPDATA']) / 'MetaQuotes' / 'Terminal'
    for d in root.iterdir() if root.is_dir() else []:
        origin = d / 'origin.txt'
        if origin.is_file():
            raw = origin.read_bytes()
            text = raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8', 'ignore')
            if Path(text.strip().strip('\ufeff')).resolve() == terminal.parent.resolve():
                return d
    sys.exit('Terminal data folder not found - pass --data-dir "%APPDATA%\\MetaQuotes\\Terminal\\<id>"')


def write_utf16(path, text):
    path.write_bytes(b'\xff\xfe' + text.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-16-le'))


def read_text_any(path):
    raw = path.read_bytes()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')
    return raw.decode('utf-8-sig', 'ignore')


def powershell(cmd):
    return subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', cmd],
                          capture_output=True, text=True).returncode


def terminal_running(terminal):
    p = str(terminal).replace("'", "''")
    return powershell(f"if (Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {{ $_.Path -eq '{p}' }}) {{ exit 0 }} else {{ exit 1 }}") == 0


def close_terminal(terminal, wait_s=120):
    """Ask the terminal to close (like clicking X) and wait; never kills it."""
    p = str(terminal).replace("'", "''")
    powershell(f"Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {{ $_.Path -eq '{p}' }} | "
               f"ForEach-Object {{ [void]$_.CloseMainWindow(); [void]$_.WaitForExit({wait_s * 1000}) }}")
    return not terminal_running(terminal)


def set_tester_tab_graph(data_dir):
    """Make the Strategy Tester open on its Graph tab (MT5 restores TesterTab on start; 3 = Graph)."""
    ini = data_dir / 'config' / 'terminal.ini'
    if ini.is_file():
        text = read_text_any(ini)
        new = re.sub(r'(?m)^TesterTab=\d+', 'TesterTab=3', text)
        if new != text:
            write_utf16(ini, new)


# --------------------------------------------------------------------------- CPU limits (ctypes)

class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD),
                ('th32DefaultHeapID', ctypes.c_void_p), ('th32ModuleID', wintypes.DWORD), ('cntThreads', wintypes.DWORD),
                ('th32ParentProcessID', wintypes.DWORD), ('pcPriClassBase', ctypes.c_long), ('dwFlags', wintypes.DWORD),
                ('szExeFile', ctypes.c_wchar * 260)]


def _kernel32():
    k32 = ctypes.windll.kernel32
    k32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k32.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    k32.OpenProcess.restype = wintypes.HANDLE
    k32.SetProcessAffinityMask.argtypes = [wintypes.HANDLE, ctypes.c_size_t]
    k32.SetPriorityClass.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    k32.CloseHandle.argtypes = [wintypes.HANDLE]
    return k32


def limit_processes(names, pids, mask):
    """Below-normal priority (and the CPU mask, if any) for the tester terminal (pids) and its agents (names)."""
    k32 = _kernel32()
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)                          # TH32CS_SNAPPROCESS
    if not snap or snap == ctypes.c_void_p(-1).value:
        return
    entry = PROCESSENTRY32W(); entry.dwSize = ctypes.sizeof(PROCESSENTRY32W)
    ok = k32.Process32FirstW(snap, ctypes.byref(entry))
    while ok:
        if entry.th32ProcessID in pids or entry.szExeFile.lower() in names:
            h = k32.OpenProcess(0x0200 | 0x0400, False, entry.th32ProcessID)    # SET_INFORMATION | QUERY_INFORMATION
            if h:
                if mask:
                    k32.SetProcessAffinityMask(h, mask)
                k32.SetPriorityClass(h, BELOW_NORMAL_PRIORITY_CLASS)
                k32.CloseHandle(h)
        ok = k32.Process32NextW(snap, ctypes.byref(entry))
    k32.CloseHandle(snap)


def default_cpu_mask():
    n = os.cpu_count() or 2
    return sum(1 << i for i in range(0, n, 2)) if n > 2 else 0        # every other logical CPU


# --------------------------------------------------------------------------- compile / plan

def compile_ea(terminal, data_dir, ea_src):
    dest_dir = data_dir / 'MQL5' / 'Experts' / EXPERT_SUBDIR
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / ea_src.name
    shutil.copy2(ea_src, dest)
    log = dest.with_suffix('.log')
    editor = terminal.parent / 'MetaEditor64.exe'
    # MetaTrader's command-line switches want the quotes around the value only: /compile:"C:\path with spaces"
    subprocess.run(f'"{editor}" /compile:"{dest}" /log:"{log}" /inc:"{data_dir / "MQL5"}"', capture_output=True)
    result = next((l for l in read_text_any(log).splitlines() if 'Result:' in l), '') if log.is_file() else ''
    print(f'compile {ea_src.name}: {result.strip() or "no compiler log"}')
    if not re.search(r'\b0 errors', result) or not dest.with_suffix('.ex5').is_file():
        sys.exit(f'Compilation failed - see {log}')
    return f'{EXPERT_SUBDIR}\\{dest.with_suffix(".ex5").name}'


def month_range(first, last):
    y, m = map(int, first.split('-')); y2, m2 = map(int, last.split('-'))
    out = []
    while (y, m) <= (y2, m2):
        out.append(f'{y:04d}-{m:02d}')
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return out


def next_month(ym):
    y, m = map(int, ym.split('-'))
    return f'{y + 1:04d}.01.01' if m == 12 else f'{y:04d}.{m + 1:02d}.01'


def safe(s):
    return re.sub(r'[^A-Za-z0-9_-]+', '-', s).strip('-')


def git_info(paths):
    def git(*a):
        r = subprocess.run(['git', '-C', str(REPO), *a], capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else ''
    commit = git('rev-parse', '--short', 'HEAD')
    dirty = git('status', '--porcelain', '--', *[str(p) for p in paths])
    return commit + (' + uncommitted changes' if dirty else '') if commit else 'unknown'


# --------------------------------------------------------------------------- run

def cmd_run(a):
    if os.name != 'nt':
        sys.exit('Windows only (MetaTrader 5)')
    terminal = find_terminal(a.terminal)
    data_dir = find_data_dir(terminal, a.data_dir)
    ea_src = (REPO / a.ea).resolve(); set_src = (REPO / a.set).resolve()
    for p in (ea_src, set_src):
        if not p.is_file():
            sys.exit(f'Not found: {p}')
    name = safe(a.name)
    out = REPO / 'reports' / name
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.gettempdir()) / 'nyao_backtest' / name      # tester configs (outside the repo)
    work.mkdir(parents=True, exist_ok=True)

    expert = compile_ea(terminal, data_dir, ea_src)
    set_name = f'nyao_bt_{name}.set'
    write_utf16(data_dir / 'MQL5' / 'Profiles' / 'Tester' / set_name, read_text_any(set_src))

    periods = [p.strip().upper() for p in a.periods.split(',') if p.strip()]
    months = month_range(a.from_month, a.to_month)
    windows = ([(m, f'{m.replace("-", ".")}.01', next_month(m)) for m in months] if a.split == 'monthly'
               else [(f'{months[0]}..{months[-1]}', f'{months[0].replace("-", ".")}.01', next_month(months[-1]))])
    runs, inis = [], {}
    for period in periods:
        for label, frm, to in windows:
            report = f'nyao_bt_{name}_{period}_{safe(label)}'
            ini = work / f'{report}.ini'
            write_utf16(ini, '\n'.join([
                '[Tester]', f'Expert={expert}', f'ExpertParameters={set_name}', f'Symbol={a.symbol}', f'Period={period}',
                f'Model={MODELS[a.model]}', 'ExecutionMode=0', 'Optimization=0', f'FromDate={frm}', f'ToDate={to}',
                'ForwardMode=0', f'Deposit={a.deposit:g}', f'Currency={a.currency}', 'ProfitInPips=0', f'Leverage=1:{a.leverage}',
                'Visual=0', 'UseLocal=1', 'UseRemote=0', 'UseCloud=0', f'Report={report}', 'ReplaceReport=1',
                'ShutdownTerminal=1', '']))
            runs.append(dict(period=period, window=label, report=report))
            inis[report] = ini

    plan = dict(name=name, title=a.title or f'{set_src.stem} on {a.symbol} {"/".join(periods)}', ea=ea_src.relative_to(REPO).as_posix(),
                set=set_src.relative_to(REPO).as_posix(), version=git_info([ea_src, set_src]), symbol=a.symbol, periods=periods,
                windows=[w[0] for w in windows], split=a.split, model=a.model, deposit=a.deposit, currency=a.currency,
                leverage=a.leverage, generated=dt.datetime.now().strftime('%Y-%m-%d %H:%M'), runs=runs)
    (out / 'plan.json').write_text(json.dumps(plan, indent=2), encoding='utf-8')

    was_running = terminal_running(terminal)
    if was_running:
        print('closing MetaTrader 5 (the tester needs it closed) ...')
        if not close_terminal(terminal):
            sys.exit('MetaTrader 5 did not close (unsaved dialog?) - close it and run again')
    mask = default_cpu_mask() if a.cpu_mask is None else int(a.cpu_mask, 0)
    try:
        for i, r in enumerate(runs, 1):
            set_tester_tab_graph(data_dir)
            start = time.time()
            proc = subprocess.Popen(f'"{terminal}" /config:"{inis[r["report"]]}"', creationflags=BELOW_NORMAL_PRIORITY_CLASS)
            status = 'done'
            while True:
                limit_processes({'metatester64.exe'}, {proc.pid}, mask)
                try:
                    proc.wait(timeout=2); break
                except subprocess.TimeoutExpired:
                    if time.time() - start > a.timeout_min * 60:
                        proc.kill(); status = 'TIMEOUT'; break
            print(f'[{i}/{len(runs)}] {r["period"]} {r["window"]}: {status} in {time.time() - start:.0f}s', flush=True)
    finally:
        if was_running and not a.no_reopen:
            subprocess.Popen([str(terminal)])
            print('MetaTrader 5 reopened')
    build_report(plan, data_dir, keep_raw=a.keep_raw)


# --------------------------------------------------------------------------- report

def parse_report(path):
    t = read_text_any(path)
    cells = [html.unescape(re.sub(r'<[^>]+>', '', c)).strip() for c in re.findall(r'<td[^>]*>(.*?)</td>', t, flags=re.S | re.I)]

    def val(key):
        for i, c in enumerate(cells):
            if c == key + ':':
                return next((v for v in cells[i + 1:i + 4] if v), '')
        return ''

    def num(s):
        s = s.replace('\xa0', '').replace(' ', '')
        m = re.match(r'-?[\d.]+', s)
        return float(m.group()) if m else 0.0

    trades = int(num(val('Total Trades')))
    wins = int(num(val('Profit Trades (% of total)')))
    dd = val('Equity Drawdown Relative')
    return dict(deposit=num(val('Initial Deposit')), net=num(val('Total Net Profit')), gross_profit=num(val('Gross Profit')),
                gross_loss=num(val('Gross Loss')), trades=trades, wins=wins, dd_pct=num(dd.split('%')[0]) if dd else 0.0,
                quality=val('History Quality'), tested_range=val('Period'))


def build_report(plan, data_dir, keep_raw=False):
    out = REPO / 'reports' / plan['name']
    graphs = out / 'graphs'
    graphs.mkdir(parents=True, exist_ok=True)
    rows = []
    for r in plan['runs']:
        htm = data_dir / f'{r["report"]}.htm'
        if not htm.is_file():
            rows.append(dict(r, missing=True)); continue
        m = parse_report(htm)
        dep = m['deposit'] or plan['deposit']
        png = data_dir / f'{r["report"]}.png'
        graph = f'graphs/{r["period"]}_{safe(r["window"])}.png'
        if png.is_file():
            shutil.copy2(png, out / graph)
        if keep_raw:
            raw = out / 'raw'; raw.mkdir(exist_ok=True)
            for f in data_dir.glob(f'{r["report"]}*'):
                shutil.copy2(f, raw / f.name)
        rows.append(dict(r, missing=False, pct=m['net'] / dep * 100, graph=graph if png.is_file() else '', **m))

    with open(out / 'results.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['period', 'window', 'net_profit', 'return_pct', 'equity_dd_pct', 'trades', 'win_trades', 'gross_profit', 'gross_loss', 'history_quality'])
        for r in rows:
            if not r['missing']:
                w.writerow([r['period'], r['window'], f'{r["net"]:.2f}', f'{r["pct"]:.2f}', f'{r["dd_pct"]:.2f}', r['trades'], r['wins'],
                            f'{r["gross_profit"]:.2f}', f'{r["gross_loss"]:.2f}', r['quality']])

    summary = {}
    for p in plan['periods']:
        pr = [r for r in rows if r['period'] == p and not r['missing']]
        if not pr:
            continue
        trades = sum(r['trades'] for r in pr); wins = sum(r['wins'] for r in pr)
        gp = sum(r['gross_profit'] for r in pr); gl = sum(r['gross_loss'] for r in pr)
        quality = sorted({r['quality'] for r in pr if r['quality']})
        summary[p] = dict(total=sum(r['pct'] for r in pr), up=sum(r['pct'] > 0 for r in pr), n=len(pr),
                          worst=min(r['pct'] for r in pr), best=max(r['pct'] for r in pr), dd=max(r['dd_pct'] for r in pr),
                          trades=trades, win=100 * wins / trades if trades else 0, avg_win=gp / wins if wins else 0,
                          avg_loss=gl / (trades - wins) if trades > wins else 0, pf=gp / -gl if gl < 0 else 0,
                          quality=', '.join(quality) or 'unknown')
    (out / 'summary.md').write_text(render_markdown(plan, rows, summary), encoding='utf-8')
    (out / 'index.html').write_text(render_html(plan, rows, summary), encoding='utf-8')
    missing = [r['report'] for r in rows if r['missing']]
    print(f'report: {out / "summary.md"}' + (f'  ({len(missing)} runs without a report: {", ".join(missing)})' if missing else ''))


def fmt_pct(v):
    return f'{v:+.1f}%'


def setup_rows(plan):
    split = 'one run per month, each starting from a fresh deposit' if plan['split'] == 'monthly' else 'one run over the whole range'
    return [('EA', f'`{plan["ea"]}`'), ('Settings', f'`{plan["set"]}`'), ('Code version', plan['version']),
            ('Symbol / timeframes', f'{plan["symbol"]} / {", ".join(plan["periods"])}'),
            ('Tick data', {'real': 'Every tick based on real ticks', 'every': 'Every tick (generated)', 'ohlc': '1 minute OHLC', 'open': 'Open prices only'}[plan['model']]),
            ('Deposit / leverage', f'{plan["deposit"]:,.0f} {plan["currency"]} / 1:{plan["leverage"]}'), ('Runs', split),
            ('Generated', f'{plan["generated"]} with `tools/backtest/nyao_backtest.py`')]


def summary_columns():
    return ['Timeframe', 'Total return', 'Profitable', 'Best / worst run', 'Max drawdown', 'Trades', 'Win rate', 'Avg win / loss', 'Profit factor', 'Tick data']


def summary_values(p, s):
    return [p, fmt_pct(s['total']), f'{s["up"]}/{s["n"]}', f'{fmt_pct(s["best"])} / {fmt_pct(s["worst"])}', f'{s["dd"]:.1f}%',
            f'{s["trades"]:,}', f'{s["win"]:.0f}%', f'${s["avg_win"]:.2f} / -${abs(s["avg_loss"]):.2f}', f'{s["pf"]:.2f}', s['quality']]


def cell_text(r):
    if r is None or r['missing']:
        return 'no report'
    return f'{fmt_pct(r["pct"])} (DD {r["dd_pct"]:.0f}%, {r["trades"]} trades)'


def render_markdown(plan, rows, summary):
    by = {(r['period'], r['window']): r for r in rows}
    md = [f'# {plan["title"]}', '', '| Setting | Value |', '|---|---|']
    md += [f'| {k} | {v} |' for k, v in setup_rows(plan)]
    md += ['', '## Summary', '']
    if plan['split'] == 'monthly':
        md += ['Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).', '']
    md += ['| ' + ' | '.join(summary_columns()) + ' |', '|' + '---|' * len(summary_columns())]
    md += ['| ' + ' | '.join(summary_values(p, s)) + ' |' for p, s in summary.items()]
    md += ['', '## Results per run', '', '| Run | ' + ' | '.join(plan['periods']) + ' |', '|---|' + '---|' * len(plan['periods'])]
    md += [f'| {w} | ' + ' | '.join(cell_text(by.get((p, w))) for p in plan['periods']) + ' |' for w in plan['windows']]
    md += ['', '## Balance graphs', '']
    for p in plan['periods']:
        md += [f'### {p}', '']
        for w in plan['windows']:
            r = by.get((p, w))
            if r and not r['missing'] and r['graph']:
                md += [f'**{w}** {fmt_pct(r["pct"])}', '', f'![{p} {w}]({r["graph"]})', '']
    return '\n'.join(md)


def render_html(plan, rows, summary):
    e = html.escape
    by = {(r['period'], r['window']): r for r in rows}
    setup = ''.join(f'<tr><th>{e(k)}</th><td>{e(v.strip("`"))}</td></tr>' for k, v in setup_rows(plan))
    head = ''.join(f'<th>{e(c)}</th>' for c in summary_columns())
    body = ''.join('<tr>' + ''.join(f'<td>{e(v)}</td>' for v in summary_values(p, s)) + '</tr>' for p, s in summary.items())
    runs_head = '<th>Run</th>' + ''.join(f'<th>{e(p)}</th>' for p in plan['periods'])

    def run_cell(r):
        if r is None or r['missing']:
            return '<td class="mut">no report</td>'
        cls = 'pos' if r['pct'] > 0 else 'neg'
        return f'<td><span class="{cls}">{fmt_pct(r["pct"])}</span> <span class="mut">DD {r["dd_pct"]:.0f}% · {r["trades"]} trades</span></td>'
    runs_body = ''.join(f'<tr><th>{e(w)}</th>' + ''.join(run_cell(by.get((p, w))) for p in plan['periods']) + '</tr>' for w in plan['windows'])
    cards = ''
    for p in plan['periods']:
        figs = ''.join(f'<figure><figcaption><b>{e(w)}</b> <span class="{"pos" if r["pct"] > 0 else "neg"}">{fmt_pct(r["pct"])}</span>'
                       f' <span class="mut">DD {r["dd_pct"]:.0f}% · {r["trades"]} trades</span></figcaption>'
                       f'<img src="{e(r["graph"])}" alt="{e(p)} {e(w)} balance graph"></figure>'
                       for w in plan['windows'] if (r := by.get((p, w))) and not r['missing'] and r['graph'])
        cards += f'<h3>{e(p)}</h3><div class="grid">{figs}</div>'
    note = '<p class="mut">Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).</p>' if plan['split'] == 'monthly' else ''
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(plan['title'])}</title><style>
:root{{--bg:#f6f7f9;--card:#fff;--fg:#1d2330;--mut:#667085;--line:#e3e6ea;--pos:#1a7f37;--neg:#cf222e}}
@media (prefers-color-scheme:dark){{:root{{--bg:#111418;--card:#1a1f26;--fg:#e6e9ee;--mut:#8b95a3;--line:#2a313b;--pos:#3fb950;--neg:#f85149}}}}
body{{margin:0;padding:16px;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,Segoe UI,sans-serif}}
main{{max-width:1200px;margin:0 auto}} h1{{font-size:22px}} h2{{font-size:17px;margin-top:28px}} h3{{font-size:15px}}
table{{border-collapse:collapse;background:var(--card);border:1px solid var(--line);margin:8px 0;display:block;overflow-x:auto}}
th,td{{padding:6px 10px;border-bottom:1px solid var(--line);text-align:left;white-space:nowrap}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(380px,1fr));gap:10px}}
figure{{margin:0;background:var(--card);border:1px solid var(--line);border-radius:8px;padding:8px}}
img{{width:100%;height:auto;display:block;background:#fff;border-radius:4px}} figcaption{{margin-bottom:6px}}
.pos{{color:var(--pos);font-weight:600}} .neg{{color:var(--neg);font-weight:600}} .mut{{color:var(--mut)}}
</style></head><body><main><h1>{e(plan['title'])}</h1><table>{setup}</table>
<h2>Summary</h2>{note}<table><tr>{head}</tr>{body}</table>
<h2>Results per run</h2><table><tr>{runs_head}</tr>{runs_body}</table>
<h2>Balance graphs</h2>{cards}</main></body></html>"""


def cmd_report(a):
    plan_file = REPO / 'reports' / safe(a.name) / 'plan.json'
    if not plan_file.is_file():
        sys.exit(f'No plan found: {plan_file} (run the "run" command first)')
    data_dir = find_data_dir(find_terminal(a.terminal), a.data_dir)
    build_report(json.loads(plan_file.read_text(encoding='utf-8')), data_dir, keep_raw=a.keep_raw)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    r = sub.add_parser('run', help='compile, run the Strategy Tester passes and build the report')
    r.add_argument('--name', required=True, help='report folder name: reports/<name>/')
    r.add_argument('--title', help='report title')
    r.add_argument('--ea', default='nyao_scalper.mq5', help='EA source in this repo (default: nyao_scalper.mq5)')
    r.add_argument('--set', default='settings/default.set', help='settings file in this repo (default: settings/default.set)')
    r.add_argument('--symbol', default='XAUUSDm')
    r.add_argument('--periods', default='M1', help='comma-separated timeframes, e.g. M1,M5')
    r.add_argument('--from', dest='from_month', required=True, help='first month, YYYY-MM')
    r.add_argument('--to', dest='to_month', required=True, help='last month, YYYY-MM (inclusive)')
    r.add_argument('--split', choices=['monthly', 'whole'], default='monthly', help='one run per month (default) or one run for the whole range')
    r.add_argument('--model', choices=list(MODELS), default='real', help='tick model (default: real ticks)')
    r.add_argument('--deposit', type=float, default=2000)
    r.add_argument('--currency', default='USD')
    r.add_argument('--leverage', type=int, default=500)
    r.add_argument('--terminal', help='path to terminal64.exe')
    r.add_argument('--data-dir', help='terminal data folder (default: detected from the terminal path)')
    r.add_argument('--cpu-mask', help='CPU affinity mask for the tester, e.g. 0x555 (default: every other CPU, 0 = all)')
    r.add_argument('--timeout-min', type=float, default=30, help='abort a single run after this many minutes')
    r.add_argument('--keep-raw', action='store_true', help='also copy the raw MT5 reports to reports/<name>/raw/ (git-ignored)')
    r.add_argument('--no-reopen', action='store_true', help='do not reopen MetaTrader 5 afterwards')
    r.set_defaults(func=cmd_run)
    p = sub.add_parser('report', help='rebuild reports/<name>/ from the existing tester reports')
    p.add_argument('--name', required=True)
    p.add_argument('--keep-raw', action='store_true')
    p.add_argument('--terminal', help='path to terminal64.exe')
    p.add_argument('--data-dir', help='terminal data folder (default: detected from the terminal path)')
    p.set_defaults(func=cmd_report)
    a = ap.parse_args()
    a.func(a)


if __name__ == '__main__':
    main()
