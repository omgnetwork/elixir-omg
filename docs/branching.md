### Branching and deployments model

This document aims to discuss and document the relations between branches and deployments of `elixir-omg`, with respect to branches and deployments of `plasma-contracts`.

It is a refinement of the [OIP4 branching model](https://github.com/omisego/OIP/blob/master/0004-ewallet-release-and-versioning.md), applicable to `elixir-omg` and `plasma-contracts` versioning.

This takes `v0.1` and `v0.2` as an example of two versions, where one is deployed in `staging`/`Ari` and the other is the upcoming upgrade and is deployed in `devel`.

Rationale:
- the history and the relations between the versions are readable and accountable,
- we can predictably sync our respective watchers/run child chain servers against deployed contracts
- and at the same time be able to move with `master`s quickly

("->" means that the `mix.exs` holds the following branch)

- `elixir-omg/v0.1` -> `plasma-contracts/v0.1`, that's understood, the `mix.lock` points to a specific frozen version, no changes expected there
- `elixir-omg/master` -> `plasma-contracts/master`, mix lock points to the contracts ~deployed on `devel`~ we want to CI-check with `elixir-omg`. So it might be newer than what contract is deployed on `devel`
- `elixir-omg/v0.2` -> `plasma-contracts/v0.2`, the commit that fixes *the branch `plasma-contracts/v0.2` in `elixir-omg`* will need to be constantly rebased onto `master`, as long we keep looping features into `elixir-omg/v0.2`. *The mix lock will always point to the contract commit currently deployed on `devel`*.

When want to integrate to a newer contract, we'll:
- make a PR to `elixir-omg/master` bumping the contract version in `mix.lock` and (possibly) providing compatibility with any possible breaking changes.
This will run CI checks on the new integration
- PR is merged
- this is the moment when `elixir-omg/master` might not sync to `devel` anymore, if changes to contract were breaking!
If they weren't breaking, we can end here, all should sync fine
- if changes were breaking:
- fast forward `plasma-contracts/v0.2` to the desired commit on `master`
- have a PR/commit/rebase to bump `mix.lock` version of `plasma-contracts` in `elixir-omg/v0.2`.

Also, if we want to upgrade contracts to be potentially promoted to `staging-v0.2`/`Ari-v0.2`, we should test on `devel` first, so we'd like to reset `devel` under such circumstances too (even if changes had been non-breaking above).

When `plasma-contracts/v0.2` finally becomes the contract version which we will push to `staging-v0.2` (and `Ari-v0.2`), `plasma-contracts/master` starts putting on new contract-features and diverges from `plasma-contracts/v0.2`
