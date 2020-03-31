use Mix.Config

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 100,
  fee_adapter_check_interval_ms: 1_000,
  fee_buffer_duration_ms: 5_000,
  fee_adapter:
    {OMG.ChildChain.Fees.FileAdapter,
     opts: [
       specs_file_path: Path.join(__DIR__, "../test/omg_child_chain/support/fee_specs.json")
     ]}
