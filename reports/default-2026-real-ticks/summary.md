# Default profile - XAUUSDm M1 vs M5, real ticks Jan-Sep 2026

| Setting | Value |
|---|---|
| EA | Nyao Scalper v47.0 (`nyao_scalper.mq5`) |
| Settings | `settings/default.set` |
| Git commit | 679fbe5 |
| Symbol / timeframes | XAUUSDm / M1, M5 |
| Tick data | Every tick based on real ticks |
| Deposit / leverage | 2,000 USD / 1:500 |
| Runs | One run per month, each starting from a fresh deposit |
| Generated | 2026-10-15 23:49 with `tools/backtest/nyao_backtest.py` |

## Summary

Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).

| Timeframe | Total return | Profitable | Best / worst run | Max drawdown | Trades | Win rate | Avg win / loss | Profit factor | Tick data |
|---|---|---|---|---|---|---|---|---|---|
| M1 | +22.0% | 5/9 | +27.9% / -17.8% | 32.3% | 1,478 | 36% | $21.12 / -$11.27 | 1.04 | 100% real ticks |
| M5 | +83.4% | 6/9 | +39.9% / -3.1% | 20.0% | 1,109 | 44% | $20.72 / -$13.43 | 1.20 | 100% real ticks |

## Results per run

| Run | M1 | M5 |
|---|---|---|
| 2026-01 | +27.9% (DD 9%, 181 trades) | +39.9% (DD 9%, 166 trades) |
| 2026-02 | -17.8% (DD 32%, 259 trades) | +1.4% (DD 19%, 202 trades) |
| 2026-03 | +10.7% (DD 16%, 277 trades) | +9.9% (DD 18%, 196 trades) |
| 2026-04 | -11.8% (DD 27%, 130 trades) | -2.8% (DD 20%, 84 trades) |
| 2026-05 | -9.6% (DD 18%, 121 trades) | +1.5% (DD 13%, 90 trades) |
| 2026-06 | +20.4% (DD 10%, 192 trades) | +35.8% (DD 8%, 153 trades) |
| 2026-07 | +2.5% (DD 14%, 106 trades) | -3.1% (DD 10%, 66 trades) |
| 2026-08 | -4.6% (DD 13%, 131 trades) | +2.8% (DD 11%, 95 trades) |
| 2026-09 | +4.2% (DD 8%, 81 trades) | -2.0% (DD 12%, 57 trades) |

## Balance graphs

### M1

**2026-01** +27.9%

![M1 2026-01](graphs/M1_2026-01.png)

**2026-02** -17.8%

![M1 2026-02](graphs/M1_2026-02.png)

**2026-03** +10.7%

![M1 2026-03](graphs/M1_2026-03.png)

**2026-04** -11.8%

![M1 2026-04](graphs/M1_2026-04.png)

**2026-05** -9.6%

![M1 2026-05](graphs/M1_2026-05.png)

**2026-06** +20.4%

![M1 2026-06](graphs/M1_2026-06.png)

**2026-07** +2.5%

![M1 2026-07](graphs/M1_2026-07.png)

**2026-08** -4.6%

![M1 2026-08](graphs/M1_2026-08.png)

**2026-09** +4.2%

![M1 2026-09](graphs/M1_2026-09.png)

### M5

**2026-01** +39.9%

![M5 2026-01](graphs/M5_2026-01.png)

**2026-02** +1.4%

![M5 2026-02](graphs/M5_2026-02.png)

**2026-03** +9.9%

![M5 2026-03](graphs/M5_2026-03.png)

**2026-04** -2.8%

![M5 2026-04](graphs/M5_2026-04.png)

**2026-05** +1.5%

![M5 2026-05](graphs/M5_2026-05.png)

**2026-06** +35.8%

![M5 2026-06](graphs/M5_2026-06.png)

**2026-07** -3.1%

![M5 2026-07](graphs/M5_2026-07.png)

**2026-08** +2.8%

![M5 2026-08](graphs/M5_2026-08.png)

**2026-09** -2.0%

![M5 2026-09](graphs/M5_2026-09.png)
