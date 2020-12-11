# Branching and deployments model

This document aims to discuss and document the relations between branches and deployments of `elixir-omg`, with respect to branches and deployments of `plasma-contracts`.

It is a refinement of the [OIP4 branching model](https://github.com/omgnetwork/OIP/blob/master/0004-ewallet-release-and-versioning.md), applicable to `elixir-omg` and `plasma-contracts` versioning.

Rationale:
- the history and the relations between the versions are readable and simple to understand
- we can predictably sync our respective watchers/run child chain servers against deployed contracts
- we can move with the `master` branch quickly


## Dependency Rules for elixir-omg

### For mix.exs
- `elixir-omg/master` will point to the `plasma-contracts/master`
- A release branch in `elixir-omg` will point to the corresponding release branch in `plasma-contracts`. For example:
  - `elixir-omg/v0.1` -> `plasma-contracts/v0.1`

### For mix.lock
- Always points to a specific SHA that in the history of the `plasma-contracts` branch referenced in `mix.exs`


## Deployment Scenarios

### 1 - Single production deployment, ongoing development

This is the active scenario most of the time.

Branches and environments:
- `master` is automatically deployed to **development** environment
- `v0.1` is automatically deployed to **staging-v0-1** environment
  - changes to the release branch will be merged into `master`, as needed
- `v0.1` is manually deployed to **production-v0-1** environment

Deploying new contracts in `master`:
- make a PR to `elixir-omg/master` bumping the contract version in `mix.lock`
- CI checks on the new integration
- merge the PR
- redeploy contracts
- redeploy child chain and watcher
- NB – contract deployment is currently a manual process, so we may be in a state where `mix.lock` points to a newer SHA than deployed on **development**. _We will correct this disparity as quickly as possible. This may mean rolling back `mix.lock`, if needed._
- TODO – Automate contract deployments in **development**

Deploying new contracts in the release branch:
- :stop_sign: - _NOPE_
- We cannot deploy any `elixir-omg` code that is incompatible with the currently deployed contracts in **staging** and **production**

### 2 - Production deployment, validating a new version for network upgrade

This is a _feature freeze_ for the new version (`v0.2` branch). Try to minimize merging changes from `master` to any of the release branches.

Branches and environments:
- `master` is automatically deployed to **development** environment
- `v0.2` is automatically deployed to **staging-v0-2** environment
  - This assumes that during the process of validating a network upgrade, all work merged onto `master` will get deployed to for the upgrade.
- `v0.1` is automatically deployed to **staging-v0-1** environment
  - Keep this environment around for hotfixes
- `v0.1` is manually deployed to **production-v0-1** environment

Deploying new contracts in `master`:
- Same as Scenario 1

Deploying new contracts in `v0.1`:
- :stop_sign: _NOPE_

Deploying new contracts to `v0.2`
- Manually deploy to **staging-v0-2**

### 3 - Production deployment, ready to deploy network upgrade to production, ongoing development

When we're confident of the stability on **staging-v0-2** and ready to go to Private Alpha, create the `v0.2` branch from `master` for both `elixir-omg` and `plasma-contracts` repos.

Most importantly, we're confident about the contracts. A contract redeployment in this phase would have the most impact.

Branches and environments:
- `master` is automatically deployed to **development** environment
- `v0.2` is automatically deployed to **staging-v0-2** environment
  - changes to this release branch will be merged into `master`, as needed
- `v0.2` is manually deployed to **production-v0-2** environment
- `v0.1` is automatically deployed to **staging-v0-1** environment
  - changes to the release branch will be merged into `master`, as needed
- `v0.1` is manually deployed to **production-v0-1** environment

Deploying new contracts to `master`:
- Same as Scenario 1

Deploying new contracts to `v0.1`
- :stop_sign: _NOPE_

Deploying new contracts to `v0.2`
- Manually deploy to **staging-v0-2** and **production-v0-2** environments, _if absolutely necessary_

### 4 - Two production deployments, ongoing development

We will have two production environments during the network upgrade, so that users have the opportunity to exit the old environment and deposit into the new environment.

Everything the same as Scenario 3 except - Deploying new contracts to `v0.2`
- :stop_sign: _NOPE_

Once this phase ends, we take down the older `production-v0-1` and `staging-v0-1` and return to Scenario 1. We may want to consider continuing to run a watcher for an old version a longer period of time.
