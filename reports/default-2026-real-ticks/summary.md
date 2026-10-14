# Default profile - XAUUSDm M1 vs M5, real ticks Jan-Sep 2026

| Setting | Value |
|---|---|
| EA | Nyao Scalper v46.0 (`nyao_scalper.mq5`) |
| Settings | `settings/default.set` |
| Git commit | 9f9a934 |
| Symbol / timeframes | XAUUSDm / M1, M5 |
| Tick data | Every tick based on real ticks |
| Deposit / leverage | 2,000 USD / 1:500 |
| Runs | One run per month, each starting from a fresh deposit |
| Generated | 2026-10-14 03:28 with `tools/backtest/nyao_backtest.py` |

## Summary

Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).

| Timeframe | Total return | Profitable | Best / worst run | Max drawdown | Trades | Win rate | Avg win / loss | Profit factor | Tick data |
|---|---|---|---|---|---|---|---|---|---|
| M1 | +16.1% | 3/9 | +37.6% / -21.3% | 35.3% | 1,393 | 41% | $21.32 / -$14.37 | 1.03 | 100% real ticks |
| M5 | +82.6% | 6/9 | +39.5% / -3.7% | 20.0% | 1,107 | 44% | $20.73 / -$13.62 | 1.20 | 100% real ticks |

## Results per run

| Run | M1 | M5 |
|---|---|---|
| 2026-01 | +37.6% (DD 8%, 172 trades) | +39.5% (DD 9%, 165 trades) |
| 2026-02 | -21.3% (DD 35%, 255 trades) | +1.4% (DD 19%, 202 trades) |
| 2026-03 | +9.6% (DD 17%, 280 trades) | +9.9% (DD 19%, 198 trades) |
| 2026-04 | -14.3% (DD 28%, 127 trades) | -2.8% (DD 20%, 84 trades) |
| 2026-05 | -6.3% (DD 17%, 111 trades) | +1.5% (DD 13%, 89 trades) |
| 2026-06 | +30.9% (DD 9%, 168 trades) | +35.5% (DD 9%, 152 trades) |
| 2026-07 | -4.5% (DD 17%, 93 trades) | -3.7% (DD 10%, 66 trades) |
| 2026-08 | -5.6% (DD 16%, 115 trades) | +3.4% (DD 11%, 95 trades) |
| 2026-09 | -9.8% (DD 18%, 72 trades) | -2.2% (DD 12%, 56 trades) |

## Balance graphs

### M1

**2026-01** +37.6%

![M1 2026-01](graphs/M1_2026-01.png)

**2026-02** -21.3%

![M1 2026-02](graphs/M1_2026-02.png)

**2026-03** +9.6%

![M1 2026-03](graphs/M1_2026-03.png)

**2026-04** -14.3%

![M1 2026-04](graphs/M1_2026-04.png)

**2026-05** -6.3%

![M1 2026-05](graphs/M1_2026-05.png)

**2026-06** +30.9%

![M1 2026-06](graphs/M1_2026-06.png)

**2026-07** -4.5%

![M1 2026-07](graphs/M1_2026-07.png)

**2026-08** -5.6%

![M1 2026-08](graphs/M1_2026-08.png)

**2026-09** -9.8%

![M1 2026-09](graphs/M1_2026-09.png)

### M5

**2026-01** +39.5%

![M5 2026-01](graphs/M5_2026-01.png)

**2026-02** +1.4%

![M5 2026-02](graphs/M5_2026-02.png)

**2026-03** +9.9%

![M5 2026-03](graphs/M5_2026-03.png)

**2026-04** -2.8%

![M5 2026-04](graphs/M5_2026-04.png)

**2026-05** +1.5%

![M5 2026-05](graphs/M5_2026-05.png)

**2026-06** +35.5%

![M5 2026-06](graphs/M5_2026-06.png)

**2026-07** -3.7%

![M5 2026-07](graphs/M5_2026-07.png)

**2026-08** +3.4%

![M5 2026-08](graphs/M5_2026-08.png)

**2026-09** -2.2%

![M5 2026-09](graphs/M5_2026-09.png)
