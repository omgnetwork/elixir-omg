# Dumps of results of perf test run over commits

## `7d219a9806cb566ede860e7a26d2b3057838ed4b`, 2018-07-05

Command:

```
mix run --no-start -e 'OMG.Performance.start_simple_perftest(8_000, 32, %{block_every_ms: 15_000})'
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
mix run --no-start -e ':observer.start(); OMG.Performance.start_simple_perftest(8_000, 32, %{block_every_ms: 15_000})'
```

Observer tells us that peak memory usage (total) is ~600MB, oscillating around ~400MB most of the time.

## `62249098e852d52552616364cb1ca9184be43d02`, 2018-10-16

Command as above:

```
mix run --no-start -e 'OMG.Performance.start_simple_perftest(8_000, 32, %{block_every_ms: 15_000})'
```

```
[
   {"blknum":1000, "span_ms":16378, "tps":3937, "txs":64484},
   {"blknum":2000, "span_ms":15115, "tps":4020, "txs":60761},
   {"blknum":3000, "span_ms":14915, "tps":4040, "txs":60257},
   {"blknum":4000, "span_ms":14726, "tps":4110, "txs":60530},
   {"blknum":5000, "span_ms":1865,  "tps":5345, "txs":9968}
]
```

typical block forming log:
```
2018-10-16 17:30:05.815 [info] ... ⋅Calculations for forming block number 2000 done in 1036 ms⋅
2018-10-16 17:30:06.312 [info] ... ⋅Forming block done in 1533 ms⋅
```

run on: as above.

## `869c964df00c17a54b399c33c8e917d23ab05dd7`, 2018-12-07

Command as above (new syntax):

```
mix run --no-start -e 'OMG.Performance.start_simple_perftest(8_000, 32, %{block_every_ms: 15_000})'
```

```
[
   {"blknum":1000, "span_ms":16488, "tps":3157, "txs":52057},
   {"blknum":2000, "span_ms":15219, "tps":2974, "txs":45254},
   {"blknum":3000, "span_ms":14964, "tps":2789, "txs":41742},
   {"blknum":4000, "span_ms":14740, "tps":2847, "txs":41965},
   {"blknum":5000, "span_ms":14889, "tps":3005, "txs":44742},
   {"blknum":6000, "span_ms":7210, "tps":4194, "txs":30240}
]
```

and

```
2018-12-07 15:14:44.129 [info] ... ⋅Calculations for forming block number 3000 done in 1391 ms⋅
```

Some drop in throughput since last dump, but still bottlenecks lie elsewhere.

## `17f73a0f90e0cec35d684da0104b97234425f787`, 2019-02-11

Command as above

```
mix run --no-start -e 'OMG.Performance.start_simple_perftest(8_000, 32, %{block_every_ms: 15_000})'
```

```
[
 {"txs": 65536, "tps": 3976, "span_ms": 16482, "blknum": 1000},
 { "txs": 65536, "tps": 4397, "span_ms": 14904, "blknum": 2000},
 { "txs": 65536, "tps": 4264, "span_ms": 15370, "blknum": 3000},
 { "txs": 59392, "tps": 5942, "span_ms": 9995, "blknum": 4000}
]
```

and
```
2019-02-11 17:16:23.392 [info] ... ⋅Calculations for forming block number 2000 done in 832 ms⋅
```

## `53dc46f80eca374c64983aacd37bd6851ec794f4`, 2019-06-28

(perf drop introduced as documented in [#731](https://github.com/omgnetwork/elixir-omg/issues/731))

Command as above

```
[
  %{blknum: 1000, span_ms: 18449, tps: 3042, txs: 56124},
  %{blknum: 2000, span_ms: 13970, tps: 3152, txs: 44029},
  %{blknum: 3000, span_ms: 15340, tps: 3125, txs: 47933},
  %{blknum: 4000, span_ms: 14598, tps: 3236, txs: 47233},
  %{blknum: 5000, span_ms: 15039, tps: 3248, txs: 48840},
  %{blknum: 6000, span_ms: 1199, tps: 9876, txs: 11841}
]
```

## `f3828a0f0a658b32a48a74649561ac2c452f7277`, 2019-06-28

(fixed the perf drop)

Command as above

```
[
  %{blknum: 1000, span_ms: 16699, tps: 3889, txs: 64940},
  %{blknum: 2000, span_ms: 14753, tps: 4007, txs: 59120},
  %{blknum: 3000, span_ms: 15225, tps: 3950, txs: 60140},
  %{blknum: 4000, span_ms: 11507, tps: 5206, txs: 59903},
  %{blknum: 5000, span_ms: 4059, tps: 2931, txs: 11897}
]
```

