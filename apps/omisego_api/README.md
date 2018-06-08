# OmiseGO child chain server

**TODO**

## Running the child chain server as operator

### Funding the operator address

The address that is running the child chain server and submitting blocks needs to be funded with ether.
At current stage this is designed as a manual process, i.e. we assume that every **gas reserve checkpoint interval**, someone will ensure that **gas reserve** worth of ether is accessible for transactions.

Gas reserve must be enough to cover gas reserve checkpoint interval of submitting blocks, assuming the most pessimistic scenario of gas price.

Calculate as follows:

```
gas_reserve = child_blocks_per_day * days_in_interval * gas_per_submission * highest_gas_price
```
where
```
child_blocks_per_day = ethereum_blocks_per_day / submit_period
```
**Submit period** is the number of Ethereum blocks per a single child block submission) - configured in `:omisego_api, :child_block_submit_period`
**Highest gas price** is the maximum gas price which operator allows when trying to have the block submission mined (operator always tries to pay less than that maximum, but has to adapt to Ethereum traffic) - configured in (**TODO** when doing [OMG-47](https://www.pivotaltracker.com/story/show/156037267))

#### Example

Assuming:
- submitting a child block every Ethereum block
- weekly cadence of funding
- highest gas price 40 Gwei
- 75071 gas per submission (checked for `RootChain.sol` used  [at this revision](https://github.com/omisego/omisego/commit/21dfb32fae82a59824aa19bbe7db87ecf33ecd04))

we get
```
gas_reserve ~= 4 * 60 * 24 / 1 * 7 * 75071 * 40 / 10**9  ~= 121 ETH
```
