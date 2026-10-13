# Default profile - XAUUSDm M1 vs M5, real ticks Jan-Sep 2026

| Setting | Value |
|---|---|
| EA | Nyao Scalper v45.0 (`nyao_scalper.mq5`) |
| Settings | `settings/default.set` |
| Git commit | 51b4596 |
| Symbol / timeframes | XAUUSDm / M1, M5 |
| Tick data | Every tick based on real ticks |
| Deposit / leverage | 2,000 USD / 1:500 |
| Runs | One run per month, each starting from a fresh deposit |
| Generated | 2026-10-13 11:12 with `tools/backtest/nyao_backtest.py` |

## Summary

Total return is the sum of the monthly returns (each month starts from the same deposit, not compounded).

| Timeframe | Total return | Profitable | Best / worst run | Max drawdown | Trades | Win rate | Avg win / loss | Profit factor | Tick data |
|---|---|---|---|---|---|---|---|---|---|
| M1 | +7.5% | 5/9 | +24.0% / -17.3% | 34.1% | 1,555 | 42% | $20.15 / -$14.58 | 1.01 | 100% real ticks |
| M5 | +51.4% | 5/9 | +34.1% / -7.8% | 20.3% | 784 | 43% | $21.84 / -$14.08 | 1.16 | 100% real ticks |

## Results per run

| Run | M1 | M5 |
|---|---|---|
| 2026-01 | +24.0% (DD 12%, 180 trades) | +34.1% (DD 6%, 109 trades) |
| 2026-02 | -17.3% (DD 34%, 226 trades) | -6.9% (DD 20%, 97 trades) |
| 2026-03 | +2.0% (DD 21%, 281 trades) | +9.5% (DD 14%, 114 trades) |
| 2026-04 | -16.1% (DD 26%, 184 trades) | -4.8% (DD 14%, 77 trades) |
| 2026-05 | +8.6% (DD 13%, 127 trades) | +8.7% (DD 7%, 75 trades) |
| 2026-06 | +19.2% (DD 17%, 188 trades) | +13.2% (DD 12%, 116 trades) |
| 2026-07 | -3.8% (DD 15%, 124 trades) | +9.5% (DD 6%, 74 trades) |
| 2026-08 | +0.5% (DD 13%, 137 trades) | -7.8% (DD 15%, 68 trades) |
| 2026-09 | -9.5% (DD 21%, 108 trades) | -4.0% (DD 11%, 54 trades) |

## Balance graphs

### M1

**2026-01** +24.0%

![M1 2026-01](graphs/M1_2026-01.png)

**2026-02** -17.3%

![M1 2026-02](graphs/M1_2026-02.png)

**2026-03** +2.0%

![M1 2026-03](graphs/M1_2026-03.png)

**2026-04** -16.1%

![M1 2026-04](graphs/M1_2026-04.png)

**2026-05** +8.6%

![M1 2026-05](graphs/M1_2026-05.png)

**2026-06** +19.2%

![M1 2026-06](graphs/M1_2026-06.png)

**2026-07** -3.8%

![M1 2026-07](graphs/M1_2026-07.png)

**2026-08** +0.5%

![M1 2026-08](graphs/M1_2026-08.png)

**2026-09** -9.5%

![M1 2026-09](graphs/M1_2026-09.png)

### M5

**2026-01** +34.1%

![M5 2026-01](graphs/M5_2026-01.png)

**2026-02** -6.9%

![M5 2026-02](graphs/M5_2026-02.png)

**2026-03** +9.5%

![M5 2026-03](graphs/M5_2026-03.png)

**2026-04** -4.8%

![M5 2026-04](graphs/M5_2026-04.png)

**2026-05** +8.7%

![M5 2026-05](graphs/M5_2026-05.png)

**2026-06** +13.2%

![M5 2026-06](graphs/M5_2026-06.png)

**2026-07** +9.5%

![M5 2026-07](graphs/M5_2026-07.png)

**2026-08** -7.8%

![M5 2026-08](graphs/M5_2026-08.png)

**2026-09** -4.0%

![M5 2026-09](graphs/M5_2026-09.png)
