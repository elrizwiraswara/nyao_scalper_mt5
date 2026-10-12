# Default profile - XAUUSDm M1 vs M5, real ticks Jan-Sep 2026

| Setting | Value |
|---|---|
| EA | `nyao_scalper.mq5` |
| Settings | `settings/default.set` |
| Code version | d0b484e |
| Symbol / timeframes | XAUUSDm / M1, M5 |
| Tick data | Every tick based on real ticks |
| Deposit / leverage | 2,000 USD / 1:500 |
| Runs | one run per month, each starting from a fresh deposit |
| Generated | 2026-10-13 01:05 with `tools/backtest/nyao_backtest.py` |

## Summary

Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).

| Timeframe | Total return | Profitable | Best / worst run | Max drawdown | Trades | Win rate | Avg win / loss | Profit factor | Tick data |
|---|---|---|---|---|---|---|---|---|---|
| M1 | -12.6% | 4/9 | +30.1% / -28.5% | 39.2% | 1,725 | 42% | $20.09 / -$14.54 | 0.98 | 100% real ticks |
| M5 | +44.1% | 5/9 | +30.8% / -9.5% | 19.0% | 928 | 42% | $21.58 / -$13.87 | 1.12 | 100% real ticks |

## Results per run

| Run | M1 | M5 |
|---|---|---|
| 2026-01 | +30.1% (DD 14%, 194 trades) | +30.8% (DD 7%, 127 trades) |
| 2026-02 | -8.5% (DD 25%, 248 trades) | -7.1% (DD 19%, 127 trades) |
| 2026-03 | +2.8% (DD 30%, 313 trades) | +4.8% (DD 17%, 139 trades) |
| 2026-04 | -17.1% (DD 26%, 194 trades) | -7.2% (DD 16%, 97 trades) |
| 2026-05 | +3.2% (DD 19%, 150 trades) | +12.3% (DD 10%, 98 trades) |
| 2026-06 | +19.0% (DD 18%, 204 trades) | +21.0% (DD 11%, 127 trades) |
| 2026-07 | -6.8% (DD 15%, 132 trades) | +7.5% (DD 8%, 77 trades) |
| 2026-08 | -6.7% (DD 14%, 144 trades) | -9.5% (DD 14%, 68 trades) |
| 2026-09 | -28.5% (DD 39%, 146 trades) | -8.6% (DD 17%, 68 trades) |

## Balance graphs

### M1

**2026-01** +30.1%

![M1 2026-01](graphs/M1_2026-01.png)

**2026-02** -8.5%

![M1 2026-02](graphs/M1_2026-02.png)

**2026-03** +2.8%

![M1 2026-03](graphs/M1_2026-03.png)

**2026-04** -17.1%

![M1 2026-04](graphs/M1_2026-04.png)

**2026-05** +3.2%

![M1 2026-05](graphs/M1_2026-05.png)

**2026-06** +19.0%

![M1 2026-06](graphs/M1_2026-06.png)

**2026-07** -6.8%

![M1 2026-07](graphs/M1_2026-07.png)

**2026-08** -6.7%

![M1 2026-08](graphs/M1_2026-08.png)

**2026-09** -28.5%

![M1 2026-09](graphs/M1_2026-09.png)

### M5

**2026-01** +30.8%

![M5 2026-01](graphs/M5_2026-01.png)

**2026-02** -7.1%

![M5 2026-02](graphs/M5_2026-02.png)

**2026-03** +4.8%

![M5 2026-03](graphs/M5_2026-03.png)

**2026-04** -7.2%

![M5 2026-04](graphs/M5_2026-04.png)

**2026-05** +12.3%

![M5 2026-05](graphs/M5_2026-05.png)

**2026-06** +21.0%

![M5 2026-06](graphs/M5_2026-06.png)

**2026-07** +7.5%

![M5 2026-07](graphs/M5_2026-07.png)

**2026-08** -9.5%

![M5 2026-08](graphs/M5_2026-08.png)

**2026-09** -8.6%

![M5 2026-09](graphs/M5_2026-09.png)
