# Dumps of results of perf test run over commits

## `7d219a9806cb566ede860e7a26d2b3057838ed4b`, 2018-07-05

Command:

```
mix run --no-start -e 'OmiseGO.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
```

Performance statistics:
```
[
  %{"blknum" => 1000, "span_ms" => 16904, "tps" => 3876.95, "txs" => 65536},
  %{"blknum" => 2000, "span_ms" => 14920, "tps" => 4050.34, "txs" => 60431},
  %{"blknum" => 3000, "span_ms" => 15428, "tps" => 3907.25, "txs" => 60281},
  %{"blknum" => 4000, "span_ms" => 14706, "tps" => 4035.5, "txs" => 59346},
  %{"blknum" => 5000, "span_ms" => 2054, "tps" => 5066.21, "txs" => 10406}
]

```

typical block forming log:
```
15:30:00.267 [info] Calculations for forming block 1000 done in 1017 ms
15:30:01.083 [info] DB.multi_update done in 816 ms
15:30:01.148 [info] Done forming block in 1898 ms
```

run on
```
4x version: Intel(R) Core(TM) i7-4790K CPU @ 4.00GHz
```

## `685b5f75b283ab64b56ae5b6ac046b99692d3fbd`, 2018-07-18

Command:

```
mix run --no-start -e ':observer.start(); OmiseGO.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
```

Observer tells us that peak memory usage (total) is ~600MB, oscillating around ~400MB most of the time.
