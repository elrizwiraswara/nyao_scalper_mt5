# Default profile - XAUUSDm M1 vs M5, real ticks Jan-Sep 2026

| Setting | Value |
|---|---|
| EA | Nyao Scalper v45.0 (`nyao_scalper.mq5`) |
| Settings | `settings/default.set` |
| Git commit | eeb53ce |
| Symbol / timeframes | XAUUSDm / M1, M5 |
| Tick data | Every tick based on real ticks |
| Deposit / leverage | 2,000 USD / 1:500 |
| Runs | One run per month, each starting from a fresh deposit |
| Generated | 2026-10-13 02:27 with `tools/backtest/nyao_backtest.py` |

## Summary

Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).

| Timeframe | Total return | Profitable | Best / worst run | Max drawdown | Trades | Win rate | Avg win / loss | Profit factor | Tick data |
|---|---|---|---|---|---|---|---|---|---|
| M1 | -14.7% | 4/9 | +24.0% / -25.8% | 37.3% | 1,618 | 42% | $20.07 / -$14.64 | 0.98 | 100% real ticks |
| M5 | +50.1% | 5/9 | +34.1% / -7.8% | 20.3% | 824 | 42% | $21.84 / -$13.94 | 1.15 | 100% real ticks |

## Results per run

| Run | M1 | M5 |
|---|---|---|
| 2026-01 | +24.0% (DD 12%, 180 trades) | +34.1% (DD 6%, 109 trades) |
| 2026-02 | -17.3% (DD 34%, 226 trades) | -6.9% (DD 20%, 97 trades) |
| 2026-03 | -2.4% (DD 28%, 296 trades) | +12.7% (DD 16%, 135 trades) |
| 2026-04 | -14.0% (DD 24%, 191 trades) | -6.5% (DD 16%, 84 trades) |
| 2026-05 | +4.9% (DD 16%, 140 trades) | +7.7% (DD 9%, 74 trades) |
| 2026-06 | +19.2% (DD 17%, 188 trades) | +13.2% (DD 12%, 116 trades) |
| 2026-07 | -3.8% (DD 15%, 124 trades) | +9.5% (DD 6%, 74 trades) |
| 2026-08 | +0.5% (DD 13%, 137 trades) | -7.8% (DD 15%, 68 trades) |
| 2026-09 | -25.8% (DD 37%, 136 trades) | -5.9% (DD 14%, 67 trades) |

## Balance graphs

### M1

**2026-01** +24.0%

![M1 2026-01](graphs/M1_2026-01.png)

**2026-02** -17.3%

![M1 2026-02](graphs/M1_2026-02.png)

**2026-03** -2.4%

![M1 2026-03](graphs/M1_2026-03.png)

**2026-04** -14.0%

![M1 2026-04](graphs/M1_2026-04.png)

**2026-05** +4.9%

![M1 2026-05](graphs/M1_2026-05.png)

**2026-06** +19.2%

![M1 2026-06](graphs/M1_2026-06.png)

**2026-07** -3.8%

![M1 2026-07](graphs/M1_2026-07.png)

**2026-08** +0.5%

![M1 2026-08](graphs/M1_2026-08.png)

**2026-09** -25.8%

![M1 2026-09](graphs/M1_2026-09.png)

### M5

**2026-01** +34.1%

![M5 2026-01](graphs/M5_2026-01.png)

**2026-02** -6.9%

![M5 2026-02](graphs/M5_2026-02.png)

**2026-03** +12.7%

![M5 2026-03](graphs/M5_2026-03.png)

**2026-04** -6.5%

![M5 2026-04](graphs/M5_2026-04.png)

**2026-05** +7.7%

![M5 2026-05](graphs/M5_2026-05.png)

**2026-06** +13.2%

![M5 2026-06](graphs/M5_2026-06.png)

**2026-07** +9.5%

![M5 2026-07](graphs/M5_2026-07.png)

**2026-08** -7.8%

![M5 2026-08](graphs/M5_2026-08.png)

**2026-09** -5.9%

![M5 2026-09](graphs/M5_2026-09.png)
