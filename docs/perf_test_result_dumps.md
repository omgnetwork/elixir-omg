# Dumps of results of perf test run over commits

## `7d219a9806cb566ede860e7a26d2b3057838ed4b`, 2018-07-05

Command:

```
mix run --no-start -e 'OMG.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
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

Command as above + observer:

```
mix run --no-start -e ':observer.start(); OMG.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
```

Observer tells us that peak memory usage (total) is ~600MB, oscillating around ~400MB most of the time.

## `62249098e852d52552616364cb1ca9184be43d02`, 2018-10-16

Command as above:

```
mix run --no-start -e 'OMG.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
```

```
[
   {"blknum":1000, "span_ms":16378, "tps":3937.23, "txs":64484},
   {"blknum":2000, "span_ms":15115, "tps":4019.91, "txs":60761},
   {"blknum":3000, "span_ms":14915, "tps":4040.03, "txs":60257},
   {"blknum":4000, "span_ms":14726, "tps":4110.42, "txs":60530},
   {"blknum":5000, "span_ms":1865,  "tps":5344.77, "txs":9968}
]
```

typical block forming log:
```
2018-10-16 17:30:05.815 [info] ... ⋅Calculations for forming block number 2000 done in 1036 ms⋅
2018-10-16 17:30:06.312 [info] ... ⋅Forming block done in 1533 ms⋅
```

run on: as above.
