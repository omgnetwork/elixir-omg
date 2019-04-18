### Branching and deployments model

This document aims to discuss and document the relations between branches and deployments of `elixir-omg`, with respect to branches and deployments of `plasma-contracts`.

It is a refinement of the [OIP4 branching model](https://github.com/omisego/OIP/blob/master/0004-ewallet-release-and-versioning.md), applicable to `elixir-omg` and `plasma-contracts` versioning.

This takes `v0.1` and `v0.2` as an example of two versions, where one is deployed in `staging`/`Ari` and the other is the upcoming upgrade and is deployed in `development`.

Rationale:
- the history and the relations between the versions are readable and accountable,
- we can predictably sync our respective watchers/run child chain servers against deployed contracts
- we can move with `master`s quickly

("->" means that the `mix.exs` holds the following branch)

- `elixir-omg/v0.1` -> `plasma-contracts/v0.1`, that's understood, the `mix.lock` points to a specific frozen version, no changes expected there
- `elixir-omg/master` -> `plasma-contracts/master`, mix lock points to the contracts ~deployed on `development`~ we want to CI-check with `elixir-omg`. So it might be newer than what contract is deployed on `development`
- `elixir-omg/v0.2` -> `plasma-contracts/v0.2`. `elixir-omg/v0.2` will have a commit that fixes *the branch `plasma-contracts/v0.2` in `mix.exs`*.
`elixir-omg/master` is going to be constantly merged into `elixir-omg/v0.2`, as long we keep merging features. However, *the `mix.lock` will always point to the contract commit currently deployed on `development`*.

When want to integrate to a newer contract, and `v0.2` isn't yet feature frozen in terms of the contract, we'll:
- make a PR to `elixir-omg/master` bumping the contract version in `mix.lock` and (possibly) providing compatibility with any possible breaking changes.
This will run CI checks on the new integration
- PR is merged
- this is the moment when `elixir-omg/master` might not sync to `development` anymore, if changes to contract were breaking!
If they weren't breaking, we can end here, all should sync fine
- if changes were breaking:
- fast forward `plasma-contracts/v0.2` to the desired commit on `master`
- merge the resulting bump of `mix.lock` contracts' version into `elixir-omg/v0.2`.

Also, if we want to upgrade contracts to be potentially promoted to `staging-v0.2`/`Ari-v0.2`, we should test on `development` first, so we'd like to reset `development` under such circumstances too (even if changes had been non-breaking above).

When `plasma-contracts/v0.2` finally becomes the contract version which we will push to `staging-v0.2` (and `Ari-v0.2`), `plasma-contracts/master` starts putting on new contract-features and diverges from `plasma-contracts/v0.2`
