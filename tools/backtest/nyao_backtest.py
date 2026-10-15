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
import functools
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
from decimal import Decimal
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EXPERT_SUBDIR = 'NyaoBacktest'
MODELS = {'every': 0, 'ohlc': 1, 'open': 2, 'real': 4}
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000


# --------------------------------------------------------------------------- terminal / files

def terminal_candidates():
    """Installed MetaTrader 5 terminals: the standard folder first, then any other Program Files folder with terminal64.exe."""
    found = []
    for var in ('ProgramW6432', 'ProgramFiles'):
        root = Path(os.environ.get(var, ''))
        if not str(root) or not root.is_dir():
            continue
        for p in [root / 'MetaTrader 5' / 'terminal64.exe', *sorted(root.glob('*/terminal64.exe'))]:
            if p.is_file() and p not in found:
                found.append(p)
    return found


def find_terminal(path):
    for p in ([Path(path)] if path else terminal_candidates()):
        if p.is_file():
            return p
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


def reopen_terminal(terminal):
    if terminal_running(terminal):
        print('MetaTrader 5 is already running - not reopened')
        return
    try:
        subprocess.Popen([str(terminal)])
    except OSError as ex:
        print(f'MetaTrader 5 could not be reopened: {ex}')
        return
    print('MetaTrader 5 reopened')


def report_files(data_dir, report):
    """A run's tester report: <report>.htm plus its .png / -hst.png / -mfemae.png / -holding.png graphs."""
    pat = re.compile(re.escape(report) + r'(?:\.htm|(?:-hst|-mfemae|-holding)?\.png)', re.I)
    return [f for f in data_dir.glob(f'{report}*') if pat.fullmatch(f.name)]


def clear_report(data_dir, report):
    """Delete a run's old report so a failed run can't show stale results."""
    for f in report_files(data_dir, report):
        try:
            f.unlink()
        except OSError as ex:
            print(f'warning: could not delete {f.name}: {ex}')


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
                ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD), ('cntThreads', wintypes.DWORD),
                ('th32ParentProcessID', wintypes.DWORD), ('pcPriClassBase', ctypes.c_long), ('dwFlags', wintypes.DWORD),
                ('szExeFile', ctypes.c_wchar * 260)]                    # th32DefaultHeapID is a ULONG_PTR


@functools.lru_cache(maxsize=None)
def _kernel32():
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)               # own instance, not the shared windll one
    k32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k32.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k32.Process32FirstW.restype = wintypes.BOOL
    k32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k32.Process32NextW.restype = wintypes.BOOL
    k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    k32.OpenProcess.restype = wintypes.HANDLE
    k32.SetProcessAffinityMask.argtypes = [wintypes.HANDLE, ctypes.c_size_t]   # DWORD_PTR
    k32.SetProcessAffinityMask.restype = wintypes.BOOL
    k32.SetPriorityClass.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    k32.SetPriorityClass.restype = wintypes.BOOL
    k32.CloseHandle.argtypes = [wintypes.HANDLE]
    k32.CloseHandle.restype = wintypes.BOOL
    return k32


def limit_processes(pid, mask):
    """Below-normal priority (and the CPU mask, if any) for the tester terminal (pid) and the
    metatester64.exe agents it started; other terminals and agents on the machine are left alone."""
    k32 = _kernel32()
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)                          # TH32CS_SNAPPROCESS
    if not snap or snap == ctypes.c_void_p(-1).value:
        return
    entry = PROCESSENTRY32W(); entry.dwSize = ctypes.sizeof(PROCESSENTRY32W)
    ok = k32.Process32FirstW(snap, ctypes.byref(entry))
    while ok:
        if entry.th32ProcessID == pid or (entry.th32ParentProcessID == pid and entry.szExeFile.lower() == 'metatester64.exe'):
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
    ex5, log = dest.with_suffix('.ex5'), dest.with_suffix('.log')
    for f in (ex5, log):                                                 # only a fresh build may pass the checks below
        try:
            f.unlink()
        except FileNotFoundError:
            pass
        except OSError as ex:
            sys.exit(f'Cannot delete the old {f} ({ex}) - close whatever is using it and run again')
    editor = terminal.parent / 'MetaEditor64.exe'
    # MetaTrader's command-line switches want the quotes around the value only: /compile:"C:\path with spaces"
    rc = subprocess.run(f'"{editor}" /compile:"{dest}" /log:"{log}" /inc:"{data_dir / "MQL5"}"', capture_output=True).returncode
    result = next((l for l in read_text_any(log).splitlines() if 'Result:' in l), '') if log.is_file() else ''
    print(f'compile {ea_src.name}: {result.strip() or "no compiler log"}')
    if rc and not ex5.is_file():                                         # MetaEditor's exit code alone is not reliable
        sys.exit(f'MetaEditor exited with code {rc} and built no {ex5.name} - see {log}')
    if not ex5.is_file() or not re.search(r'\b0 errors', result):
        sys.exit(f'Compilation failed - see {log}')
    return f'{EXPERT_SUBDIR}\\{ex5.name}'


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


def plain_number(x):
    """12345.67 -> '12345.67', 1000000.0 -> '1000000': no exponent, no rounding."""
    s = format(Decimal(repr(float(x))), 'f')
    return s.rstrip('0').rstrip('.') if '.' in s else s


def save_plan(plan):
    (REPO / 'reports' / plan['name'] / 'plan.json').write_text(json.dumps(plan, indent=2), encoding='utf-8')


def ea_version(ea_src):
    """'44.0' from `#property version "44.0"` in the EA source ('' if not found)."""
    try:
        m = re.search(r'#property\s+version\s+"([^"]+)"', read_text_any(Path(ea_src)))
        return m.group(1) if m else ''
    except OSError:
        return ''


def ea_label(plan):
    v = plan.get('ea_version', '')
    stem = Path(plan['ea']).stem
    name = 'Nyao Scalper' if stem == 'nyao_scalper' else stem.replace('_', ' ').title()
    return f'{name} v{v}' if v else name


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
                'ForwardMode=0', f'Deposit={plain_number(a.deposit)}', f'Currency={a.currency}', 'ProfitInPips=0', f'Leverage=1:{a.leverage}',
                'Visual=0', 'UseLocal=1', 'UseRemote=0', 'UseCloud=0', f'Report={report}', 'ReplaceReport=1',
                'ShutdownTerminal=1', '']))
            runs.append(dict(period=period, window=label, report=report, status='not run'))
            inis[report] = ini

    plan = dict(name=name, title=a.title or f'{set_src.stem} on {a.symbol} {"/".join(periods)}', ea=ea_src.relative_to(REPO).as_posix(),
                set=set_src.relative_to(REPO).as_posix(), version=git_info([ea_src, set_src]), ea_version=ea_version(ea_src), symbol=a.symbol, periods=periods,
                windows=[w[0] for w in windows], split=a.split, model=a.model, deposit=a.deposit, currency=a.currency,
                leverage=a.leverage, generated=dt.datetime.now().strftime('%Y-%m-%d %H:%M'), runs=runs)
    save_plan(plan)

    was_running = terminal_running(terminal)
    if was_running:
        print('closing MetaTrader 5 (the tester needs it closed) ...')
        if not close_terminal(terminal):
            sys.exit('MetaTrader 5 did not close (unsaved dialog?) - close it and run again')
    mask = default_cpu_mask() if a.cpu_mask is None else int(a.cpu_mask, 0)
    proc = None
    try:
        for i, r in enumerate(runs, 1):
            clear_report(data_dir, r['report'])
            set_tester_tab_graph(data_dir)
            start = time.time()
            r['status'] = 'interrupted'                                  # until this run finishes
            proc = subprocess.Popen(f'"{terminal}" /config:"{inis[r["report"]]}"', creationflags=BELOW_NORMAL_PRIORITY_CLASS)
            status = 'done'
            while True:
                limit_processes(proc.pid, mask)
                try:
                    proc.wait(timeout=2); break
                except subprocess.TimeoutExpired:
                    if time.time() - start > a.timeout_min * 60:
                        proc.kill(); proc.wait(); status = 'TIMEOUT'; break
            htm = data_dir / f'{r["report"]}.htm'
            if status == 'done' and not (htm.is_file() and htm.stat().st_mtime >= start - 2):   # missing or not rewritten
                status = 'no report'
            r['status'] = status
            print(f'[{i}/{len(runs)}] {r["period"]} {r["window"]}: {status} in {time.time() - start:.0f}s', flush=True)
    finally:
        if proc is not None and proc.poll() is None:                    # stopped mid-run: end the tester first
            proc.kill(); proc.wait()
        save_plan(plan)
        if was_running and not a.no_reopen:
            reopen_terminal(terminal)
    build_report(plan, data_dir, keep_raw=a.keep_raw)


# --------------------------------------------------------------------------- report

def parse_report(path):
    """Key numbers from an MT5 tester report, or None when its English labels are missing."""
    t = read_text_any(path)
    cells = [html.unescape(re.sub(r'<[^>]+>', '', c)).strip() for c in re.findall(r'<td[^>]*>(.*?)</td>', t, flags=re.S | re.I)]

    def val(key):
        for i, c in enumerate(cells):
            if c == key + ':':
                return next((v for v in cells[i + 1:i + 4] if v), '')
        return None                                                     # label not in the report

    def num(s):
        s = (s or '').replace('\xa0', '').replace(' ', '')
        m = re.match(r'-?\d+(?:\.\d+)?', s)
        return float(m.group()) if m else 0.0

    trades = int(num(val('Total Trades')))
    need = ['Initial Deposit', 'Total Net Profit', 'Gross Profit', 'Gross Loss', 'Total Trades']
    need += ['Profit Trades (% of total)', 'Loss Trades (% of total)'] if trades else []
    lost = [k for k in need if val(k) is None]
    if lost:
        print(f'warning: {path.name}: labels not found ({", ".join(lost)}) - the MT5 terminal language must be English')
        return None
    dd = val('Equity Drawdown Relative') or ''
    return dict(deposit=num(val('Initial Deposit')), net=num(val('Total Net Profit')), gross_profit=num(val('Gross Profit')),
                gross_loss=num(val('Gross Loss')), trades=trades, wins=int(num(val('Profit Trades (% of total)'))),
                losses=int(num(val('Loss Trades (% of total)'))), dd_pct=num(dd.split('%')[0]) if dd else 0.0,
                quality=val('History Quality') or '', tested_range=val('Period') or '')


def build_report(plan, data_dir, keep_raw=False):
    if 'ea_version' not in plan:
        plan['ea_version'] = ea_version(REPO / plan['ea'])
        save_plan(plan)
    out = REPO / 'reports' / plan['name']
    graphs = out / 'graphs'
    graphs.mkdir(parents=True, exist_ok=True)
    rows = []
    for r in plan['runs']:
        status = r.get('status', 'done')                                # older plans have no status
        htm = data_dir / f'{r["report"]}.htm'
        if status != 'done' or not htm.is_file():                       # never read a report the run didn't write
            rows.append(dict(r, missing=True, status=status if status != 'done' else 'no report')); continue
        m = parse_report(htm)
        if m is None:
            rows.append(dict(r, missing=True, status='unparsed')); continue
        dep = m['deposit'] or plan['deposit']
        png = data_dir / f'{r["report"]}.png'
        graph = f'graphs/{r["period"]}_{safe(r["window"])}.png'
        if png.is_file():
            shutil.copy2(png, out / graph)
        if keep_raw:
            raw = out / 'raw'; raw.mkdir(exist_ok=True)
            for f in report_files(data_dir, r['report']):
                shutil.copy2(f, raw / f.name)
        rows.append(dict(r, missing=False, pct=m['net'] / dep * 100, graph=graph if png.is_file() else '', **m))

    with open(out / 'results.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['period', 'window', 'net_profit', 'return_pct', 'equity_dd_pct', 'trades', 'win_trades', 'loss_trades',
                    'gross_profit', 'gross_loss', 'history_quality'])
        for r in rows:
            if not r['missing']:
                w.writerow([r['period'], r['window'], f'{r["net"]:.2f}', f'{r["pct"]:.2f}', f'{r["dd_pct"]:.2f}', r['trades'], r['wins'],
                            r['losses'], f'{r["gross_profit"]:.2f}', f'{r["gross_loss"]:.2f}', r['quality']])

    summary = {}
    for p in plan['periods']:
        pr = [r for r in rows if r['period'] == p and not r['missing']]
        if not pr:
            continue
        trades = sum(r['trades'] for r in pr); wins = sum(r['wins'] for r in pr); losses = sum(r['losses'] for r in pr)
        gp = sum(r['gross_profit'] for r in pr); gl = sum(r['gross_loss'] for r in pr)
        quality = sorted({r['quality'] for r in pr if r['quality']})
        summary[p] = dict(total=sum(r['pct'] for r in pr), up=sum(r['pct'] > 0 for r in pr), n=len(pr),
                          worst=min(r['pct'] for r in pr), best=max(r['pct'] for r in pr), dd=max(r['dd_pct'] for r in pr),
                          trades=trades, win=100 * wins / trades if trades else 0, avg_win=gp / wins if wins else 0,
                          avg_loss=gl / losses if losses else 0,
                          pf=gp / -gl if losses and gl < 0 else float('inf') if wins else None,   # no losses: inf, no trades: None
                          quality=', '.join(quality) or 'unknown')
    (out / 'summary.md').write_text(render_markdown(plan, rows, summary), encoding='utf-8')
    (out / 'index.html').write_text(render_html(plan, rows, summary), encoding='utf-8')
    missing = [f'{r["report"]} ({r["status"]})' for r in rows if r['missing']]
    print(f'report: {out / "summary.md"}' + (f'  ({len(missing)} runs without a report: {", ".join(missing)})' if missing else ''))


def fmt_pct(v):
    return f'{v:+.1f}%'


def fmt_pf(pf):
    return '-' if pf is None else '∞' if pf == float('inf') else f'{pf:.2f}'


def setup_rows(plan):
    split = 'One run per month, each starting from a fresh deposit' if plan['split'] == 'monthly' else 'One run over the whole range'
    return [('EA', f'{ea_label(plan)} (`{plan["ea"]}`)'), ('Settings', f'`{plan["set"]}`'), ('Git commit', plan['version']),
            ('Symbol / timeframes', f'{plan["symbol"]} / {", ".join(plan["periods"])}'),
            ('Tick data', {'real': 'Every tick based on real ticks', 'every': 'Every tick (generated)', 'ohlc': '1 minute OHLC', 'open': 'Open prices only'}[plan['model']]),
            ('Deposit / leverage', f'{plan["deposit"]:,.0f} {plan["currency"]} / 1:{plan["leverage"]}'), ('Runs', split),
            ('Generated', f'{plan["generated"]} with `tools/backtest/nyao_backtest.py`')]


def summary_columns():
    return ['Timeframe', 'Total return', 'Profitable', 'Best / worst run', 'Max drawdown', 'Trades', 'Win rate', 'Avg win / loss', 'Profit factor', 'Tick data']


def summary_values(p, s):
    return [p, fmt_pct(s['total']), f'{s["up"]}/{s["n"]}', f'{fmt_pct(s["best"])} / {fmt_pct(s["worst"])}', f'{s["dd"]:.1f}%',
            f'{s["trades"]:,}', f'{s["win"]:.0f}%', f'${s["avg_win"]:.2f} / -${abs(s["avg_loss"]):.2f}', fmt_pf(s['pf']), s['quality']]


def cell_text(r):
    if r is None or r['missing']:
        return r['status'] if r else 'no report'
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


# Dark report theme: framed column with section lines and corner squares, cells that share their border lines
REPORT_CSS = """
:root{color-scheme:dark;--bg:#121314;--surface:#18191b;--surface-2:#1f2022;--text:#f5f5f5;--muted:#a9abae;--faint:#75777c;
--border:#26282a;--border-strong:#34373a;--accent:#ffb547;--accent-hover:#ffc670;--success:#4ade80;--danger:#ff7b72;
--radius-ui:6px;--frame:1360px;--pad:clamp(20px,4vw,48px);--gutter:16px;
--sans:'Geist',system-ui,sans-serif;--mono:'Geist Mono',ui-monospace,'Cascadia Code',Menlo,Consolas,monospace}
@media (max-width:560px){:root{--pad:16px;--gutter:10px}}
*,*::before,*::after{box-sizing:border-box}
html{background:var(--bg);-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.6 var(--sans);-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
a{color:var(--text);text-decoration:none}a:hover{color:var(--accent)}
img{max-width:100%;height:auto}
::selection{background:var(--accent);color:var(--bg)}
h1,h2,h3{margin:0 0 .5em;line-height:1.15;font-weight:600;letter-spacing:-.02em}
.mono{font-family:var(--mono)}.muted{color:var(--muted)}.faint{color:var(--faint)}
.pos{color:var(--success)}.neg{color:var(--danger)}
/* Frame system: full-width bands, a framed column with corner squares, cells that share their lines */
.band{position:relative;border-top:1px solid var(--border)}
.frame{position:relative;width:min(var(--frame),calc(100% - 2*var(--gutter)));margin-inline:auto;border-inline:1px solid var(--border)}
.band>.frame::before,.band>.frame::after{content:'';position:absolute;top:-5px;z-index:2;width:9px;height:9px;border:1px solid var(--border-strong);background:var(--bg)}
.band>.frame::before{left:-5px}.band>.frame::after{right:-5px}
.spacer>.frame{height:clamp(16px,3.2vw,56px)}
main>.spacer:first-child{border-top:0}main>.spacer:first-child>.frame::before,main>.spacer:first-child>.frame::after{display:none}
.cells{display:grid;margin-bottom:-1px}
.cells>*{position:relative}
.cells>*::before,.cells>*::after{content:'';position:absolute;z-index:1;background:var(--border);pointer-events:none}
.cells>*::after{top:0;right:-1px;width:1px;height:calc(100% + 1px)}
.cells>*::before{bottom:-1px;left:0;width:calc(100% + 1px);height:1px}
.section-title{margin:0;padding:clamp(28px,4vw,40px) var(--pad);font:500 clamp(18px,2.2vw,22px)/1.2 var(--mono);letter-spacing:-.01em}
.slashes{color:var(--accent);font-weight:400}
.tag{display:inline-block;padding:2px 8px;border:1px solid var(--border-strong);border-radius:4px;background:var(--surface);color:var(--muted);font:11.5px/1.6 var(--mono);white-space:nowrap}
/* Header and footer */
.site-header{position:sticky;top:0;z-index:20;border-bottom:1px solid var(--border);background:rgb(18 19 20/.85);backdrop-filter:blur(12px)}
.bar{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:8px 24px;width:min(var(--frame),calc(100% - 2*var(--gutter)));min-height:72px;margin-inline:auto}
.brand{display:inline-flex;align-items:center;gap:12px;font-weight:600;letter-spacing:-.02em}
.brand .tag{font-weight:400}
.links{display:flex;gap:20px;font:13.5px var(--mono)}.links a{color:var(--muted)}.links a:hover{color:var(--accent)}
.site-footer .bar{padding-block:18px;color:var(--faint);font:13px var(--mono)}
.site-footer a{color:var(--muted)}
/* Intro */
.intro{padding:clamp(32px,6vw,64px) var(--pad);border-top:1px solid var(--border)}
.intro h1{max-width:24ch;margin:0;font-size:clamp(32px,5vw,52px);line-height:1.05;letter-spacing:-.045em}
.lead{max-width:64ch;margin:20px 0 0;color:var(--muted);font-size:18px}.lead b{color:var(--text);font-weight:600}
/* Setup cells */
.setup{grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));border-top:1px solid var(--border)}
.setup>div{padding:clamp(18px,2.4vw,28px) var(--pad)}
.label{display:block;margin-bottom:8px;color:var(--faint);font:12px var(--mono);letter-spacing:.02em}
.setup .value{font-size:15px;word-break:break-word}
/* Summary cells */
.summary{grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr));border-top:1px solid var(--border)}
.summary>div{padding:clamp(24px,3vw,36px) var(--pad)}
.big{display:block;margin:14px 0 2px;font-size:clamp(40px,5vw,56px);font-weight:600;line-height:1;letter-spacing:-.045em}
.metrics{margin:22px 0 0;display:grid;gap:0}
.metrics div{display:flex;justify-content:space-between;gap:16px;padding:9px 0;border-top:1px solid var(--border)}
.metrics dt{color:var(--muted);font-size:14.5px}.metrics dd{margin:0;font:14px var(--mono);text-align:right}
/* Table */
.table-wrap{overflow-x:auto;border-top:1px solid var(--border)}
table{width:100%;border-collapse:collapse;font-size:15px}
th,td{padding:12px var(--pad);border-bottom:1px solid var(--border);text-align:left;white-space:nowrap}
thead th{color:var(--faint);font:500 12px var(--mono);letter-spacing:.02em}
tbody th{font:500 14px var(--mono)}
tbody tr:hover{background:var(--surface)}
td .ret{font:600 15px var(--mono)}td .sub{margin-left:10px;color:var(--faint);font:12.5px var(--mono)}
tbody tr:last-child th,tbody tr:last-child td{border-bottom:0}
/* Graphs */
.tf{margin:0;padding:18px var(--pad);border-top:1px solid var(--border);font:500 15px var(--mono)}
.graphs{grid-template-columns:repeat(auto-fill,minmax(min(100%,360px),1fr));border-top:1px solid var(--border)}
.graphs figure{margin:0;padding:clamp(16px,2vw,24px)}
.graphs figcaption{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px 10px;margin-bottom:12px;font:13.5px var(--mono)}
.graphs figcaption b{color:var(--text);font-weight:500}
.graphs img{display:block;width:100%;border:1px solid var(--border);border-radius:var(--radius-ui);background:#fff}
.note{padding:clamp(20px,3vw,28px) var(--pad);border-top:1px solid var(--border);color:var(--muted);font-size:14.5px}
.note p{margin:0 0 .6em}.note p:last-child{margin:0}
@media (max-width:640px){.links{display:none}}
"""


def render_html(plan, rows, summary):
    e = html.escape
    by = {(r['period'], r['window']): r for r in rows}
    year = plan['generated'][:4]
    tick = {'real': 'real ticks', 'every': 'generated ticks', 'ohlc': '1-minute OHLC', 'open': 'open prices'}[plan['model']]
    windows = plan['windows']
    span = windows[0] if len(windows) == 1 else f'{windows[0]} to {windows[-1]}'

    def sign_cls(v):
        return 'pos' if v > 0 else 'neg' if v < 0 else ''

    def band(inner, title=None):
        head = f'<h2 class="section-title"><span class="slashes">//</span> {e(title)}</h2>' if title else ''
        return f'<section class="band"><div class="frame">{head}{inner}</div></section>'

    spacer = '<div class="band spacer" aria-hidden="true"><div class="frame"></div></div>'

    intro = (f'<p class="section-title"><span class="slashes">//</span> Backtest Report</p>'
             f'<div class="intro"><h1>{e(plan["title"])}</h1>'
             f'<p class="lead"><b>{e(ea_label(plan))}</b> with <b>{e(plan["set"])}</b> on {e(plan["symbol"])} {e(", ".join(plan["periods"]))}, '
             f'{e(tick)}, {e(span)}. '
             + ('Each month is a separate run starting from the same deposit.' if plan['split'] == 'monthly' else 'One run over the whole period.')
             + '</p></div>')

    setup = ''.join(f'<div><span class="label">{e(k)}</span><span class="value">{e(v.replace("`", ""))}</span></div>' for k, v in setup_rows(plan))

    cards = ''
    for p, s in summary.items():
        metrics = [('Profitable runs', f'{s["up"]} / {s["n"]}'), ('Best / worst run', f'{fmt_pct(s["best"])} / {fmt_pct(s["worst"])}'),
                   ('Max drawdown', f'{s["dd"]:.1f}%'), ('Profit factor', fmt_pf(s['pf'])), ('Trades', f'{s["trades"]:,}'),
                   ('Win rate', f'{s["win"]:.0f}%'), ('Avg win / loss', f'${s["avg_win"]:.2f} / -${abs(s["avg_loss"]):.2f}'),
                   ('Tick data', s['quality'])]
        dl = ''.join(f'<div><dt>{e(k)}</dt><dd>{e(v)}</dd></div>' for k, v in metrics)
        total_label = 'Total return (sum of runs)' if plan['split'] == 'monthly' else 'Total return'
        cards += (f'<div><span class="tag">{e(p)}</span><span class="big {sign_cls(s["total"])}">{fmt_pct(s["total"])}</span>'
                  f'<span class="muted">{e(total_label)}</span><dl class="metrics">{dl}</dl></div>')

    def run_cell(r):
        if r is None or r['missing']:
            return f'<td class="faint">{e(r["status"] if r else "no report")}</td>'
        return (f'<td><span class="ret {sign_cls(r["pct"])}">{fmt_pct(r["pct"])}</span>'
                f'<span class="sub">DD {r["dd_pct"]:.0f}% · {r["trades"]} trades</span></td>')
    thead = '<tr><th>Run</th>' + ''.join(f'<th>{e(p)}</th>' for p in plan['periods']) + '</tr>'
    tbody = ''.join(f'<tr><th>{e(w)}</th>' + ''.join(run_cell(by.get((p, w))) for p in plan['periods']) + '</tr>' for w in windows)
    table = f'<div class="table-wrap"><table><thead>{thead}</thead><tbody>{tbody}</tbody></table></div>'

    graphs = ''
    for p in plan['periods']:
        figs = ''.join(f'<figure><figcaption><b>{e(w)}</b><span class="{sign_cls(r["pct"])}">{fmt_pct(r["pct"])}</span>'
                       f'<span class="faint">DD {r["dd_pct"]:.0f}% · {r["trades"]} trades</span></figcaption>'
                       f'<img src="{e(r["graph"])}" alt="{e(p)} {e(w)} balance graph" loading="lazy"></figure>'
                       for w in windows if (r := by.get((p, w))) and not r['missing'] and r['graph'])
        if figs:
            graphs += f'<h3 class="tf">{e(p)}</h3><div class="cells graphs">{figs}</div>'

    note = ('<div class="note">'
            + ('<p>Total return is the sum of the monthly returns: each month starts from the same deposit, so it is not compounded.</p>' if plan['split'] == 'monthly' else '')
            + '<p>Backtests are not a guarantee of future results. Trading Forex and CFDs involves significant risk; '
              'forward-test on a demo account before using real money.</p></div>')

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(plan['title'])}</title><meta name="theme-color" content="#121314">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>{REPORT_CSS}</style></head>
<body>
<header class="site-header"><div class="bar">
<span class="brand">{e(ea_label(plan))} <span class="tag">Backtest Report</span></span>
<nav class="links" aria-label="Links"><a href="https://github.com/elrizwiraswara/nyao_scalper_mt5">GitHub &#8599;</a></nav>
</div></header>
<main>
{spacer}
{band(intro)}
{spacer}
{band(f'<div class="cells setup">{setup}</div>', 'Setup')}
{spacer}
{band(f'<div class="cells summary">{cards}</div>', 'Summary')}
{spacer}
{band(table, 'Results per Run')}
{spacer}
{band(graphs, 'Balance Graphs')}
{spacer}
{band(note, 'Notes')}
{spacer}
</main>
<footer class="band site-footer"><div class="bar"><span>Generated with tools/backtest/nyao_backtest.py</span><a href="https://github.com/elrizwiraswara/nyao_scalper_mt5">github.com/elrizwiraswara/nyao_scalper_mt5</a></div></footer>
</body></html>
"""


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
