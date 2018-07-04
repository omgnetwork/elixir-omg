# Dumps of results of perf test run over commits

## `324c9d044060adf35c30d21eda62bf24139b8a98`, 2018-07-05

Command:

```
mix run --no-start -e 'OmiseGO.Performance.setup_and_run(8_000, 32, %{block_every_ms: 15_000})'
```

```
Performance statistics:
[
  %{blknum: 1000, span_ms: 16186, tps: 2650.44, txs: 42900},
  %{blknum: 2000, span_ms: 14957, tps: 2681.62, txs: 40109},
  %{blknum: 3000, span_ms: 14830, tps: 2711.4, txs: 40210},
  %{blknum: 4000, span_ms: 15079, tps: 2687.38, txs: 40523},
  %{blknum: 5000, span_ms: 15080, tps: 2664.99, txs: 40188},
  %{blknum: 6000, span_ms: 14843, tps: 2696.56, txs: 40025},
  %{blknum: 7000, span_ms: 3760, tps: 3203.46, txs: 12045}
]
```

typical block forming log:
```
00:42:18.788 [info] Calculations for forming block 4000 done in 566 ms
00:42:19.227 [info] DB.multi_update done in 438 ms
00:42:19.254 [info] Done forming block in 1032 ms
```
