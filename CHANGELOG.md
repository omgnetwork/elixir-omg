# Changelog

## Unreleased

#### APIs
- None

#### Core
- None

#### Miscellaneous
- None

## [v0.4.6](https://github.com/omisego/elixir-omg/releases/tag/v0.4.6)

Compatible with [`plasma-contracts@v1.0.4`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.4).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.5...v0.4.6).

#### APIs
- None

#### Core
- [Added] Pool size and transactions in block metrics (#1391)
- [Changed] Contracts lockdown on boot and gas telemetry for block submission (#1382)
- [Changed] Cleanup (#1407)
- [Changed] rpc calls consolidate (#1376)

#### Miscellaneous
- [Changed] bump Ink package version (#1387)
- [Fixed] Exclude hostname (#1390)
- [Changed] Fixed missing creating_txhash, spending_txhash (#1396)
- [Added] Automated dependency audits (#1393)
- [Changed] Make docker-nuke should reset geth snapshot (#1386)
- [Changed] update exit_validation.md documentation (#1388)
- [Added] Implement Code Owners for mix.lock (#1406)

## [v0.4.5](https://github.com/omisego/elixir-omg/releases/tag/v0.4.5)

Compatible with [`plasma-contracts@v1.0.4`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.4).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.4...v0.4.5).

#### APIs
- None

#### Core
- [Changed] Upgrade to plasma-contracts@v1.0.4 (#1382)
- [Fixed] Fix "piggyback_available" popping back after challenge (#1372)

#### Miscellaneous
- [Added] Add end-to-end tests for invalid exits (#1344)
- [Changed] Improvements to load test stability (#1381)

## [v0.4.4](https://github.com/omisego/elixir-omg/releases/tag/v0.4.4) (2020-03-02)

Compatible with [`plasma-contracts@v1.0.3`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.3).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.3...v0.4.4).

#### APIs
- None

#### Core
- [Added] Set LOGGING_BACKEND=INK for json logging (#1352)
- [Fixed] watcher_info crashing when receiving a block with large number of transactions (#1356)

#### Miscellaneous
- [Added] Publish BlockSubmitted event internally (#1351)

## [v0.4.3](https://github.com/omisego/elixir-omg/tree/v0.4.3) (2020-02-26)

Compatible with [`plasma-contracts@v1.0.3`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.3).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.2...v0.4.3).

#### APIs
- [Added] [`watcher_info`](https://developer.omisego.co/elixir-omg/docs-ui/?urls.primaryName=0.4%2Finfo_api_specs) returns new `inserted_at` and `updated_at` fields in `/account.get_transactions`, `/block.get`, `/block.all`, `/transaction.all`, `/transaction.get` (#1322)
- [Added] [`watcher_info`](https://developer.omisego.co/elixir-omg/docs-ui/?urls.primaryName=0.4%2Finfo_api_specs) returns a new `updated_at` field in `/fees.all` (#1322)
- [Fixed] Increase a request's maximum header value length from 4096 to 8096 (#1331)
- [Fixed] Internal server errors returned when making requests to unsupported endpoints (#1339)

#### Core
- [Added] Add release name, app env and hostname to datadog events (#1345)
- [Fixed] Align `docker-compose-watcher.yml` with the latest version (#1341)

#### Miscellaneous
- [Added] Use open-api generated client to run tests (#1330)
- [Added] Add `make api_specs` that generates all API specs at once (#1335)
- [Added] Publish docker images on version tags (#1343)

## [v0.4.2](https://github.com/omisego/elixir-omg/tree/v0.4.2) (2020-02-24)

Compatible with [`plasma-contracts@v1.0.3`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.3).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.1...v0.4.2).

#### APIs
- [Fixed] API responses return the current version 0.4.2 instead of 0.3.0 (#1338)

#### Core
- None

#### Miscellaneous
- [Added] CI to publish docker images on version branches (#1340)

## [v0.4.1](https://github.com/omisego/elixir-omg/tree/v0.4.1) (2020-02-20)

Compatible with [`plasma-contracts@v1.0.3`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.3).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.4.0...v0.4.1).

#### APIs
- [Added] Add output types and transaction types to DB and API (#1314)

#### Core
- **[Breaking]** Upgrade compatibility to Geth 1.9.11 (#1329)
- **[Breaking]** Upgrade compatibility to [plasma-contracts@v1.0.3](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.3) (#1329)
- [Added] Watchers refuse to boot when sla_margin is unsafe (#1321)

#### Miscellaneous
- [Fixed] Push events to DD (#1294)
- [Fixed] Formatter using * without wildcard (#1328)

## [v0.4.0](https://github.com/omisego/elixir-omg/tree/v0.4.0) (2020-02-19)

Compatible with [`plasma-contracts@v1.0.2`](https://github.com/omisego/plasma-contracts/releases/tag/v1.0.2).
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.3.0...v0.4.0).

## [v0.3.0](https://github.com/omisego/elixir-omg/tree/v0.3.0) (2019-11-15)
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.2.3...v0.3.0).

## [v0.2.3](https://github.com/omisego/elixir-omg/tree/v0.2.3) (2019-09-25)
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.2.2...v0.2.3).

## [v0.2.2](https://github.com/omisego/elixir-omg/tree/v0.2.2) (2019-08-28)
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.2.1...v0.2.2).

## [v0.2.1](https://github.com/omisego/elixir-omg/tree/v0.2.1) (2019-06-08)
See [full changelog](https://github.com/omisego/elixir-omg/compare/v0.2.0...v0.2.1).

**Closed issues:**

- Add transaction.all pagination [\#725](https://github.com/omisego/elixir-omg/issues/725)

**Merged pull requests:**

- fix: get cors settings from proper app [\#768](https://github.com/omisego/elixir-omg/pull/768) ([InoMurko](https://github.com/InoMurko))
- 725 transaction list pagination [\#763](https://github.com/omisego/elixir-omg/pull/763) ([pnowosie](https://github.com/pnowosie))

## [v0.2.0](https://github.com/omisego/elixir-omg/tree/v0.2.0) (2019-06-07)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.5...v0.2.0)

**Closed issues:**

- BlockGetter will proceed syncing if there's no blocks after an invalid block [\#703](https://github.com/omisego/elixir-omg/issues/703)
- Transaction data missing an input on Ari [\#695](https://github.com/omisego/elixir-omg/issues/695)
- Watcher startup succeeds with errors for fresh deployments [\#691](https://github.com/omisego/elixir-omg/issues/691)
- get\_challenge\_data raise error [\#673](https://github.com/omisego/elixir-omg/issues/673)
- status.get endpoint might timeout and crash if Watcher is very busy [\#541](https://github.com/omisego/elixir-omg/issues/541)
- Starting Watcher after fully syncing with 1.5M txs [\#724](https://github.com/omisego/elixir-omg/issues/724)
- Watcher is no longer listening on 7434 [\#760](https://github.com/omisego/elixir-omg/issues/760)
- Samrong transactions can't be decoded [\#740](https://github.com/omisego/elixir-omg/issues/740)
- Body-less request requires content-type header [\#738](https://github.com/omisego/elixir-omg/issues/738)
- Decouple the smart contract deployment mechanism from the Childchain [\#734](https://github.com/omisego/elixir-omg/issues/734)
- Make sure v0.2 API is updated in swagger docs [\#727](https://github.com/omisego/elixir-omg/issues/727)
- Port \#604 from `v0.1` to master [\#726](https://github.com/omisego/elixir-omg/issues/726)
- Find Transaction by Metadata hash [\#722](https://github.com/omisego/elixir-omg/issues/722)
- Standalone Watcher deployment [\#713](https://github.com/omisego/elixir-omg/issues/713)
- Update Swagger specs [\#690](https://github.com/omisego/elixir-omg/issues/690)
- Transaction metadata should not be \_required\_ to be 32 bytes in length [\#688](https://github.com/omisego/elixir-omg/issues/688)
- Watcher /transaction.get should return metadata [\#687](https://github.com/omisego/elixir-omg/issues/687)
- Change signing typedData Ouput to use 'currency' instead of 'token' [\#677](https://github.com/omisego/elixir-omg/issues/677)
- Operator API docs are broken [\#676](https://github.com/omisego/elixir-omg/issues/676)
- Authority account unlocked on geth. Childchain reports locked [\#662](https://github.com/omisego/elixir-omg/issues/662)
- Path is a directory but has no mix.exs [\#659](https://github.com/omisego/elixir-omg/issues/659)
- Prepare EIP-712 metamask signing demo on development env [\#655](https://github.com/omisego/elixir-omg/issues/655)
- UTXOs consolidations for convenient exit [\#638](https://github.com/omisego/elixir-omg/issues/638)
- Watcher allows for spending in-flight exited utxos [\#630](https://github.com/omisego/elixir-omg/issues/630)
- Add support for LevelDB replacement [\#628](https://github.com/omisego/elixir-omg/issues/628)
- Verification of network parameters during startup [\#621](https://github.com/omisego/elixir-omg/issues/621)
- Heavily test exits on staging [\#615](https://github.com/omisego/elixir-omg/issues/615)
- Producing and verifying transaction.submit attestations [\#610](https://github.com/omisego/elixir-omg/issues/610)
- Allow to omit content-type header if no param sent in watcher API [\#590](https://github.com/omisego/elixir-omg/issues/590)
- Builds on master result in high CPU use for the Watcher [\#572](https://github.com/omisego/elixir-omg/issues/572)
- Horizontally scale child chain servers [\#561](https://github.com/omisego/elixir-omg/issues/561)
- Use omg\_rpc for omg\_watcher \(or not!\) [\#559](https://github.com/omisego/elixir-omg/issues/559)
- Expose application alarms [\#558](https://github.com/omisego/elixir-omg/issues/558)
- Performance metrics [\#550](https://github.com/omisego/elixir-omg/issues/550)

**Merged pull requests:**

- fix: Typo [\#762](https://github.com/omisego/elixir-omg/pull/762) ([jbunce](https://github.com/jbunce))
- because we have a very special bootup :-\) [\#761](https://github.com/omisego/elixir-omg/pull/761) ([InoMurko](https://github.com/InoMurko))
- 590 Remove 'Content-Type' header enforcing [\#759](https://github.com/omisego/elixir-omg/pull/759) ([pnowosie](https://github.com/pnowosie))
- 559 web api p2 [\#757](https://github.com/omisego/elixir-omg/pull/757) ([InoMurko](https://github.com/InoMurko))
- Enable `specdiffs` for Dialyzer and fix some dialyzer issues [\#756](https://github.com/omisego/elixir-omg/pull/756) ([achiurizo](https://github.com/achiurizo))
- fix: rename omg\_rpc to omg\_child\_chain\_rpc [\#755](https://github.com/omisego/elixir-omg/pull/755) ([InoMurko](https://github.com/InoMurko))
- fix: wrong module name [\#753](https://github.com/omisego/elixir-omg/pull/753) ([InoMurko](https://github.com/InoMurko))
- fix: Revert removal of --no-start [\#751](https://github.com/omisego/elixir-omg/pull/751) ([jbunce](https://github.com/jbunce))
- fix: fix starting watcher [\#750](https://github.com/omisego/elixir-omg/pull/750) ([pthomalla](https://github.com/pthomalla))
- fix: Remove --no-start from mix ecto.reset [\#749](https://github.com/omisego/elixir-omg/pull/749) ([jbunce](https://github.com/jbunce))
- feature: swap DB type via env [\#748](https://github.com/omisego/elixir-omg/pull/748) ([InoMurko](https://github.com/InoMurko))
- feature: swap DB type via env [\#747](https://github.com/omisego/elixir-omg/pull/747) ([InoMurko](https://github.com/InoMurko))
- feature: make local watcher run a proper OTP release [\#746](https://github.com/omisego/elixir-omg/pull/746) ([InoMurko](https://github.com/InoMurko))
- feat: more responsiveness for BlockGetter by adding BlockGetter.Status [\#745](https://github.com/omisego/elixir-omg/pull/745) ([pdobacz](https://github.com/pdobacz))
- 727 api compliance with v02 [\#744](https://github.com/omisego/elixir-omg/pull/744) ([pnowosie](https://github.com/pnowosie))
- fix: fix docker compose to handle DB conn & startup correctly [\#743](https://github.com/omisego/elixir-omg/pull/743) ([pdobacz](https://github.com/pdobacz))
- docs: document that docker-compose 1.24 works but 1.17 might not [\#742](https://github.com/omisego/elixir-omg/pull/742) ([pdobacz](https://github.com/pdobacz))
- fix: libsecp256k1 doesn't work in a release [\#741](https://github.com/omisego/elixir-omg/pull/741) ([InoMurko](https://github.com/InoMurko))
- docs: explain nonces restriction \(nonces problem\) in docs [\#737](https://github.com/omisego/elixir-omg/pull/737) ([pdobacz](https://github.com/pdobacz))
- feat: Add docker-compose for Watcher only deployments [\#736](https://github.com/omisego/elixir-omg/pull/736) ([jbunce](https://github.com/jbunce))
- refactor: port specs format from v0.1 to master [\#733](https://github.com/omisego/elixir-omg/pull/733) ([pnowosie](https://github.com/pnowosie))
- fix: use Stream for the large collections of known\_txs in ExitProcessor [\#732](https://github.com/omisego/elixir-omg/pull/732) ([pdobacz](https://github.com/pdobacz))
- chore: update copyright year to 2019 [\#730](https://github.com/omisego/elixir-omg/pull/730) ([achiurizo](https://github.com/achiurizo))
- Add Pull Request Template [\#729](https://github.com/omisego/elixir-omg/pull/729) ([achiurizo](https://github.com/achiurizo))
- 579 publish release docker p2 [\#728](https://github.com/omisego/elixir-omg/pull/728) ([InoMurko](https://github.com/InoMurko))
- feat: return rich syncing information from /status.get [\#708](https://github.com/omisego/elixir-omg/pull/708) ([pdobacz](https://github.com/pdobacz))
- Proper ife response handler [\#706](https://github.com/omisego/elixir-omg/pull/706) ([pdobacz](https://github.com/pdobacz))
- Port 701 704 from v0.1 [\#705](https://github.com/omisego/elixir-omg/pull/705) ([pdobacz](https://github.com/pdobacz))
- fix: make BlockGetter take a not-ok-chain into account when syncing [\#704](https://github.com/omisego/elixir-omg/pull/704) ([pdobacz](https://github.com/pdobacz))
- fix: make deposits written to WatcherDB always come before getter's txs [\#701](https://github.com/omisego/elixir-omg/pull/701) ([pdobacz](https://github.com/pdobacz))
- fix: Update CircleCI for development Samrong [\#700](https://github.com/omisego/elixir-omg/pull/700) ([jbunce](https://github.com/jbunce))
- feat: improve error logs when BlockQueue has problems, ports \#685 [\#699](https://github.com/omisego/elixir-omg/pull/699) ([pdobacz](https://github.com/pdobacz))
- feat: add get\_extable\_utxos to watcher security-critical API [\#696](https://github.com/omisego/elixir-omg/pull/696) ([pthomalla](https://github.com/pthomalla))
- feat: Add support to launcher.py for Infura [\#694](https://github.com/omisego/elixir-omg/pull/694) ([jbunce](https://github.com/jbunce))
- Simplified branching and deployment process [\#692](https://github.com/omisego/elixir-omg/pull/692) ([kasima](https://github.com/kasima))
- Add metadata to `transaction.get` endpoint output [\#689](https://github.com/omisego/elixir-omg/pull/689) ([pnowosie](https://github.com/pnowosie))
- refactor: prefix and configuration cleanup [\#686](https://github.com/omisego/elixir-omg/pull/686) ([InoMurko](https://github.com/InoMurko))
- feat: improve error logs when BlockQueue has problems [\#685](https://github.com/omisego/elixir-omg/pull/685) ([pdobacz](https://github.com/pdobacz))
- Refactor ExitProcessor.Core \(tidy exit processor pt4\) [\#684](https://github.com/omisego/elixir-omg/pull/684) ([pdobacz](https://github.com/pdobacz))
- leveldb default [\#683](https://github.com/omisego/elixir-omg/pull/683) ([InoMurko](https://github.com/InoMurko))
- Dockerfile cmake [\#682](https://github.com/omisego/elixir-omg/pull/682) ([InoMurko](https://github.com/InoMurko))
- apt install cmake [\#681](https://github.com/omisego/elixir-omg/pull/681) ([InoMurko](https://github.com/InoMurko))
- fix: not raise exceptions during get\_challenge\_data [\#678](https://github.com/omisego/elixir-omg/pull/678) ([pthomalla](https://github.com/pthomalla))
- Replay prevention for EIP-712  structural signatures [\#675](https://github.com/omisego/elixir-omg/pull/675) ([pnowosie](https://github.com/pnowosie))
- bump version to v0.1.5 [\#674](https://github.com/omisego/elixir-omg/pull/674) ([pdobacz](https://github.com/pdobacz))
- docs: clarify the confusing bit about socket route for watcher channels [\#668](https://github.com/omisego/elixir-omg/pull/668) ([pdobacz](https://github.com/pdobacz))
- setup containers with releases [\#666](https://github.com/omisego/elixir-omg/pull/666) ([InoMurko](https://github.com/InoMurko))
- fix: make odd length string error logs in tests go away [\#658](https://github.com/omisego/elixir-omg/pull/658) ([pdobacz](https://github.com/pdobacz))
- 628 rocksdb support [\#653](https://github.com/omisego/elixir-omg/pull/653) ([InoMurko](https://github.com/InoMurko))
- fix: finalize in-flight exits in Watcher [\#646](https://github.com/omisego/elixir-omg/pull/646) ([pgebal](https://github.com/pgebal))
- Fix wrong filename for 0.1 operator api spec [\#643](https://github.com/omisego/elixir-omg/pull/643) ([mederic-p](https://github.com/mederic-p))
- fix: make ExitProcessor tolerate spending blocks not being found [\#642](https://github.com/omisego/elixir-omg/pull/642) ([pdobacz](https://github.com/pdobacz))
- refactor: db abstraction [\#629](https://github.com/omisego/elixir-omg/pull/629) ([InoMurko](https://github.com/InoMurko))
- Performance metrics [\#616](https://github.com/omisego/elixir-omg/pull/616) ([pthomalla](https://github.com/pthomalla))
- Initial CHANGELOG [\#603](https://github.com/omisego/elixir-omg/pull/603) ([kasima](https://github.com/kasima))

## [v0.1.6](https://github.com/omisego/elixir-omg/tree/v0.1.6) (2019-06-25)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.2.1...v0.1.6)

**Closed issues:**

- Sentry configuration kills Logger [\#789](https://github.com/omisego/elixir-omg/issues/789)
- Is CORS enabled on the Childchain? [\#782](https://github.com/omisego/elixir-omg/issues/782)
- OMG-363 - Watcher get.block by number [\#721](https://github.com/omisego/elixir-omg/issues/721)

**Merged pull requests:**

- chore: bump version to v0.1.6 [\#804](https://github.com/omisego/elixir-omg/pull/804) ([pdobacz](https://github.com/pdobacz))
- Watcher rpc dont listen on dev [\#799](https://github.com/omisego/elixir-omg/pull/799) ([pnowosie](https://github.com/pnowosie))
- update docker-compose directions in README [\#798](https://github.com/omisego/elixir-omg/pull/798) ([achiurizo](https://github.com/achiurizo))
- fix: Service 'watcher' depends on service 'postgres' which is undefined. [\#797](https://github.com/omisego/elixir-omg/pull/797) ([InoMurko](https://github.com/InoMurko))
- fix: Finally fix this condition [\#795](https://github.com/omisego/elixir-omg/pull/795) ([jbunce](https://github.com/jbunce))
- Use `APP\_ENV` for Sentry environment [\#794](https://github.com/omisego/elixir-omg/pull/794) ([achiurizo](https://github.com/achiurizo))
- fix: Bash syntax [\#791](https://github.com/omisego/elixir-omg/pull/791) ([jbunce](https://github.com/jbunce))
- fix: Change from waiting for k8s readiness to full e2e [\#790](https://github.com/omisego/elixir-omg/pull/790) ([jbunce](https://github.com/jbunce))
- 782 ch cors [\#783](https://github.com/omisego/elixir-omg/pull/783) ([InoMurko](https://github.com/InoMurko))
- fix: Sleep time increase to allow Watcher to deploy [\#780](https://github.com/omisego/elixir-omg/pull/780) ([jbunce](https://github.com/jbunce))
- fix: f you bash [\#779](https://github.com/omisego/elixir-omg/pull/779) ([jbunce](https://github.com/jbunce))
- feat: Add functional tests to master commits [\#776](https://github.com/omisego/elixir-omg/pull/776) ([jbunce](https://github.com/jbunce))
- Chore: Update installation instructions for Linux [\#773](https://github.com/omisego/elixir-omg/pull/773) ([chrishunt](https://github.com/chrishunt))
- feature: subscribe to block change [\#772](https://github.com/omisego/elixir-omg/pull/772) ([InoMurko](https://github.com/InoMurko))
- Add Sentry for exception reporting [\#771](https://github.com/omisego/elixir-omg/pull/771) ([achiurizo](https://github.com/achiurizo))
- style: move dialyzer ignore directive to dialyzer-igore file [\#769](https://github.com/omisego/elixir-omg/pull/769) ([pnowosie](https://github.com/pnowosie))
- fix: general fixes [\#764](https://github.com/omisego/elixir-omg/pull/764) ([InoMurko](https://github.com/InoMurko))
- fix: remove the quadratic cost of finding double spends for IFE txs [\#754](https://github.com/omisego/elixir-omg/pull/754) ([pdobacz](https://github.com/pdobacz))
- Add `docker-compose` and `docker-compose.dev` [\#793](https://github.com/omisego/elixir-omg/pull/793) ([achiurizo](https://github.com/achiurizo))

## [v0.1.5](https://github.com/omisego/elixir-omg/tree/v0.1.5) (2019-05-07)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.4...v0.1.5)

**Closed issues:**

- Multiple fee\_specs.json conflict [\#660](https://github.com/omisego/elixir-omg/issues/660)
- Support chain\_id parameter in contract code [\#633](https://github.com/omisego/elixir-omg/issues/633)
- Fix dialyzer wrong derived type from dependency [\#632](https://github.com/omisego/elixir-omg/issues/632)
- Fix performance issues with producing merkle proofs in `merkle\_tree` v1.5.0 [\#626](https://github.com/omisego/elixir-omg/issues/626)
- /status.get requires a `Content-Type` header while not requiring a body [\#601](https://github.com/omisego/elixir-omg/issues/601)
- Endpoints with utxo positions as inputs don't tolerate badly encoded inputs [\#594](https://github.com/omisego/elixir-omg/issues/594)
- Endpoints taking in encoded txbytes might crash the ExitProcessor [\#591](https://github.com/omisego/elixir-omg/issues/591)
- Fix/Research slow /transaction.all endpoint [\#589](https://github.com/omisego/elixir-omg/issues/589)
- EIP-712 signing support [\#551](https://github.com/omisego/elixir-omg/issues/551)
- can't challenge an invalid exit from deposit UTXO [\#511](https://github.com/omisego/elixir-omg/issues/511)
- Fix the annoying non-failing error messages in integration tests [\#492](https://github.com/omisego/elixir-omg/issues/492)
- Using {:system, "DATABASE\_URL"} for your :url configuration is deprecated. [\#479](https://github.com/omisego/elixir-omg/issues/479)
- Elixir 1.8 Exceptions in test [\#401](https://github.com/omisego/elixir-omg/issues/401)
- personal\_unlockAccount JSON Request encoding breaks Parity compatibility  [\#270](https://github.com/omisego/elixir-omg/issues/270)

**Merged pull requests:**

- fix: Add Gorli to v0.1 [\#669](https://github.com/omisego/elixir-omg/pull/669) ([jbunce](https://github.com/jbunce))
- docs: clarify the confusing bit about socket route for watcher channels [\#668](https://github.com/omisego/elixir-omg/pull/668) ([pdobacz](https://github.com/pdobacz))
- Fix dialyzer warning on alert.ex [\#667](https://github.com/omisego/elixir-omg/pull/667) ([achiurizo](https://github.com/achiurizo))
- fix: porting introspection [\#664](https://github.com/omisego/elixir-omg/pull/664) ([InoMurko](https://github.com/InoMurko))
- fix: porting circleci configuration [\#661](https://github.com/omisego/elixir-omg/pull/661) ([InoMurko](https://github.com/InoMurko))
- Dependency compliance eip-712 signature test [\#656](https://github.com/omisego/elixir-omg/pull/656) ([pnowosie](https://github.com/pnowosie))
- fix: no need for reloader [\#654](https://github.com/omisego/elixir-omg/pull/654) ([InoMurko](https://github.com/InoMurko))
- feat: Add CD for services connected to Parity [\#652](https://github.com/omisego/elixir-omg/pull/652) ([jbunce](https://github.com/jbunce))
- fix: GÖRLI -\> GORLI [\#651](https://github.com/omisego/elixir-omg/pull/651) ([jbunce](https://github.com/jbunce))
- fix: Support Gorli contracts & add support for the Watcher [\#650](https://github.com/omisego/elixir-omg/pull/650) ([jbunce](https://github.com/jbunce))
- fix: Make the launcher work with Gorli [\#649](https://github.com/omisego/elixir-omg/pull/649) ([jbunce](https://github.com/jbunce))
- feature: parallel coveralls [\#647](https://github.com/omisego/elixir-omg/pull/647) ([InoMurko](https://github.com/InoMurko))
- Deploying with faucet addres instead of first [\#645](https://github.com/omisego/elixir-omg/pull/645) ([pnowosie](https://github.com/pnowosie))
- fix: make ExitProcessor tolerate spending blocks not being found [\#642](https://github.com/omisego/elixir-omg/pull/642) ([pdobacz](https://github.com/pdobacz))
- fix: make ExitProcessor tolerate spending blocks not being found [\#641](https://github.com/omisego/elixir-omg/pull/641) ([pdobacz](https://github.com/pdobacz))
- feat: Add Gorli to launcher.py [\#639](https://github.com/omisego/elixir-omg/pull/639) ([jbunce](https://github.com/jbunce))
- tidy exit processor pt3 - `ExitProcessor.CoreTest` [\#631](https://github.com/omisego/elixir-omg/pull/631) ([pdobacz](https://github.com/pdobacz))
- Update api docs with latest specs [\#624](https://github.com/omisego/elixir-omg/pull/624) ([mederic-p](https://github.com/mederic-p))
- Part 1 - EIP 712 signing support \(elixir-omg\) [\#623](https://github.com/omisego/elixir-omg/pull/623) ([pnowosie](https://github.com/pnowosie))
- docs: fix incorrect statement in in\_flight\_exit\_scenarios.md [\#620](https://github.com/omisego/elixir-omg/pull/620) ([kevsul](https://github.com/kevsul))
- tidy exit processor pt2: refactor: rewrite SE challenges, add tests [\#618](https://github.com/omisego/elixir-omg/pull/618) ([pdobacz](https://github.com/pdobacz))
- 579 otp release [\#617](https://github.com/omisego/elixir-omg/pull/617) ([InoMurko](https://github.com/InoMurko))
- feat: Add AppSignal deployment marker to launcher.py [\#612](https://github.com/omisego/elixir-omg/pull/612) ([pdobacz](https://github.com/pdobacz))
- cherrypick fix transaction all [\#611](https://github.com/omisego/elixir-omg/pull/611) ([pdobacz](https://github.com/pdobacz))
- tidy exit processor pt1 - `ExitProcessor` [\#609](https://github.com/omisego/elixir-omg/pull/609) ([pdobacz](https://github.com/pdobacz))
- Remove content-type requirement for /status.get [\#607](https://github.com/omisego/elixir-omg/pull/607) ([T-Dnzt](https://github.com/T-Dnzt))
- feat: Add AppSignal deployment marker to launcher.py [\#606](https://github.com/omisego/elixir-omg/pull/606) ([jbunce](https://github.com/jbunce))
- Add refactored API docs for 0.1 [\#605](https://github.com/omisego/elixir-omg/pull/605) ([mederic-p](https://github.com/mederic-p))
- Refactor swagger docs [\#604](https://github.com/omisego/elixir-omg/pull/604) ([mederic-p](https://github.com/mederic-p))
- feat: Add migrations to v0.1 launcher [\#600](https://github.com/omisego/elixir-omg/pull/600) ([jbunce](https://github.com/jbunce))
- 594 fix utxo pos decodes dialyzer [\#599](https://github.com/omisego/elixir-omg/pull/599) ([InoMurko](https://github.com/InoMurko))
- Feature/erc20 deposits demo [\#598](https://github.com/omisego/elixir-omg/pull/598) ([ebarakos](https://github.com/ebarakos))
- fix: handle malformed txbytes as inputs to IFE-related endpoints [\#593](https://github.com/omisego/elixir-omg/pull/593) ([pdobacz](https://github.com/pdobacz))
- fix: handle malformed txbytes as inputs to IFE-related endpoints [\#592](https://github.com/omisego/elixir-omg/pull/592) ([pdobacz](https://github.com/pdobacz))
- fix: remove utils dependency, ensure it works without it [\#587](https://github.com/omisego/elixir-omg/pull/587) ([InoMurko](https://github.com/InoMurko))
- 579 otp release [\#585](https://github.com/omisego/elixir-omg/pull/585) ([InoMurko](https://github.com/InoMurko))
- refactor: rename api to childchain [\#584](https://github.com/omisego/elixir-omg/pull/584) ([InoMurko](https://github.com/InoMurko))
- chore: use defferd\_config when setting database url in prod [\#533](https://github.com/omisego/elixir-omg/pull/533) ([pgebal](https://github.com/pgebal))

## [v0.1.4](https://github.com/omisego/elixir-omg/tree/v0.1.4) (2019-04-08)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.3...v0.1.4)

**Closed issues:**

- Error handling for missing signature [\#568](https://github.com/omisego/elixir-omg/issues/568)
- Clean up configuration [\#560](https://github.com/omisego/elixir-omg/issues/560)
- Move omg\_rpc supervision tree from omg\_api to omg\_rpc [\#557](https://github.com/omisego/elixir-omg/issues/557)
- Better separation of concerns between child chain and watcher [\#556](https://github.com/omisego/elixir-omg/issues/556)
- MacOS Mojave setup instruction \(w/o docker\) [\#535](https://github.com/omisego/elixir-omg/issues/535)
- Deposit to child chain not working [\#528](https://github.com/omisego/elixir-omg/issues/528)
- Config override issue with omg\_watcher [\#451](https://github.com/omisego/elixir-omg/issues/451)

**Merged pull requests:**

- removed --no-start [\#588](https://github.com/omisego/elixir-omg/pull/588) ([kendricktan](https://github.com/kendricktan))
- fix: Remove --no-start from db migration [\#586](https://github.com/omisego/elixir-omg/pull/586) ([jbunce](https://github.com/jbunce))
- fix: silence the Phoenix.Socket connect logs to debug too [\#583](https://github.com/omisego/elixir-omg/pull/583) ([pdobacz](https://github.com/pdobacz))
- fix: move session signing into env var [\#581](https://github.com/omisego/elixir-omg/pull/581) ([InoMurko](https://github.com/InoMurko))
- refactor: put all mix config entries in `config.exs` files, document [\#578](https://github.com/omisego/elixir-omg/pull/578) ([pdobacz](https://github.com/pdobacz))
- fix: silence channel join logs [\#577](https://github.com/omisego/elixir-omg/pull/577) ([pdobacz](https://github.com/pdobacz))
- \#557 rpc refactor [\#576](https://github.com/omisego/elixir-omg/pull/576) ([InoMurko](https://github.com/InoMurko))
- changed dockerized watcher database port [\#575](https://github.com/omisego/elixir-omg/pull/575) ([pnowosie](https://github.com/pnowosie))
- Phoenix.PubSub for :omg sending stuff to :omg\_api and :omg\_watcher [\#574](https://github.com/omisego/elixir-omg/pull/574) ([pdobacz](https://github.com/pdobacz))
- Omg 443 unique deposit [\#573](https://github.com/omisego/elixir-omg/pull/573) ([pik694](https://github.com/pik694))
- refactor: move emitting exit\_finalized events to ExitProcessor [\#569](https://github.com/omisego/elixir-omg/pull/569) ([pdobacz](https://github.com/pdobacz))
- feature: introspection of development env [\#567](https://github.com/omisego/elixir-omg/pull/567) ([InoMurko](https://github.com/InoMurko))
- Omg 427 scan update docs [\#566](https://github.com/omisego/elixir-omg/pull/566) ([pdobacz](https://github.com/pdobacz))
- docs: mention all JSON-RPC apis that need to be enabled by parity [\#564](https://github.com/omisego/elixir-omg/pull/564) ([paulperegud](https://github.com/paulperegud))
- fix: alarms raised in the appropriate application and passed as param, removed supervision tree [\#563](https://github.com/omisego/elixir-omg/pull/563) ([InoMurko](https://github.com/InoMurko))
- Omg 430 fix the annoying non failing error messages in integration tests [\#562](https://github.com/omisego/elixir-omg/pull/562) ([pthomalla](https://github.com/pthomalla))
- fix: allow dual-syncs of geth and watcher [\#554](https://github.com/omisego/elixir-omg/pull/554) ([pdobacz](https://github.com/pdobacz))
- fix: make spender getting not use Transaction.Recovered.recover\_from [\#553](https://github.com/omisego/elixir-omg/pull/553) ([pdobacz](https://github.com/pdobacz))
- \[OMG-403\] transaction getters should filter out empty values [\#552](https://github.com/omisego/elixir-omg/pull/552) ([pnowosie](https://github.com/pnowosie))
- \[Omg 442\] transaction.create: making empty transaction incorrect [\#548](https://github.com/omisego/elixir-omg/pull/548) ([pnowosie](https://github.com/pnowosie))
- Omg 189 tidy tx api and tests [\#547](https://github.com/omisego/elixir-omg/pull/547) ([pdobacz](https://github.com/pdobacz))
- refactor: test locations [\#546](https://github.com/omisego/elixir-omg/pull/546) ([InoMurko](https://github.com/InoMurko))
- feat: handle parity's "won't replace, gas price is too low" error [\#545](https://github.com/omisego/elixir-omg/pull/545) ([paulperegud](https://github.com/paulperegud))
- OMG-218 refactor: vm stats [\#544](https://github.com/omisego/elixir-omg/pull/544) ([InoMurko](https://github.com/InoMurko))
- OMG-218 feature: getting metrics on leveldb usage \(read,multiread,write\) [\#543](https://github.com/omisego/elixir-omg/pull/543) ([InoMurko](https://github.com/InoMurko))
- feat: parity rpc specific errors [\#542](https://github.com/omisego/elixir-omg/pull/542) ([paulperegud](https://github.com/paulperegud))
- fix: protecting OMG.DB from refactors in OMG.Block [\#539](https://github.com/omisego/elixir-omg/pull/539) ([pdobacz](https://github.com/pdobacz))
- chore: update and clean deps, remove not needed [\#538](https://github.com/omisego/elixir-omg/pull/538) ([InoMurko](https://github.com/InoMurko))
- fix: start sasl for alarms [\#537](https://github.com/omisego/elixir-omg/pull/537) ([InoMurko](https://github.com/InoMurko))
- Improving docker startup [\#536](https://github.com/omisego/elixir-omg/pull/536) ([pnowosie](https://github.com/pnowosie))
- Omg 438 cant challenge an invalid exit from deposit utxo [\#530](https://github.com/omisego/elixir-omg/pull/530) ([pthomalla](https://github.com/pthomalla))
- refactor: split the common part to omg from omg\_api [\#529](https://github.com/omisego/elixir-omg/pull/529) ([pdobacz](https://github.com/pdobacz))
- OMG-413 fix: enable PORT env variable for :dev environment + update docs [\#517](https://github.com/omisego/elixir-omg/pull/517) ([pdobacz](https://github.com/pdobacz))

## [v0.1.3](https://github.com/omisego/elixir-omg/tree/v0.1.3) (2019-03-22)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.2...v0.1.3)

**Closed issues:**

- Can't find sources for jakebunce/contractexchanger [\#496](https://github.com/omisego/elixir-omg/issues/496)
- Piggybacked outputs are reported as available when calling status.get endpoint in Watcher [\#495](https://github.com/omisego/elixir-omg/issues/495)
- Deploying Rootchain contract to local geth in dev mode fails with “exceeds block gas limit” error [\#493](https://github.com/omisego/elixir-omg/issues/493)
- Fix child chain servers gas price selection mechanism [\#436](https://github.com/omisego/elixir-omg/issues/436)
- Integration tests failure on Mac OS [\#187](https://github.com/omisego/elixir-omg/issues/187)

**Merged pull requests:**

- docs: set targetgaslimit when starting dev geth [\#532](https://github.com/omisego/elixir-omg/pull/532) ([pgebal](https://github.com/pgebal))
- Omg 399 illegality of tx with holes - \#1 [\#531](https://github.com/omisego/elixir-omg/pull/531) ([pnowosie](https://github.com/pnowosie))
- Update and clear API specs about transactions metadata [\#525](https://github.com/omisego/elixir-omg/pull/525) ([pnowosie](https://github.com/pnowosie))
- Omg 428 groom test coverage, part II - the rest [\#524](https://github.com/omisego/elixir-omg/pull/524) ([pdobacz](https://github.com/pdobacz))
- fix: check compilation without warnings in lint [\#523](https://github.com/omisego/elixir-omg/pull/523) ([InoMurko](https://github.com/InoMurko))
- feat: Use a modern Ubuntu version [\#522](https://github.com/omisego/elixir-omg/pull/522) ([jbunce](https://github.com/jbunce))
- feat: Bump Ubuntu version to get latest bpf packages [\#521](https://github.com/omisego/elixir-omg/pull/521) ([jbunce](https://github.com/jbunce))
- refactor: removing sentry as dependency [\#520](https://github.com/omisego/elixir-omg/pull/520) ([InoMurko](https://github.com/InoMurko))
- Omg 419 client connectivity watcher [\#519](https://github.com/omisego/elixir-omg/pull/519) ([InoMurko](https://github.com/InoMurko))
- feat: Add sysstat package for system diagnostics [\#518](https://github.com/omisego/elixir-omg/pull/518) ([jbunce](https://github.com/jbunce))
- Omg 428 groom test coverage - part I - omg\_api [\#516](https://github.com/omisego/elixir-omg/pull/516) ([pdobacz](https://github.com/pdobacz))
- fix: FeeServer.update\_fee\_spec [\#515](https://github.com/omisego/elixir-omg/pull/515) ([pthomalla](https://github.com/pthomalla))
- feat: Add Watcher preservation of data to staging and Ari [\#514](https://github.com/omisego/elixir-omg/pull/514) ([jbunce](https://github.com/jbunce))
- fix: increase the amount of restarts per max\_seconds [\#512](https://github.com/omisego/elixir-omg/pull/512) ([InoMurko](https://github.com/InoMurko))
- fix: allow the challenge of SE be made by an IFE transaction [\#510](https://github.com/omisego/elixir-omg/pull/510) ([pdobacz](https://github.com/pdobacz))
- Omg-435: add transaction metadata to watcherdb [\#509](https://github.com/omisego/elixir-omg/pull/509) ([pnowosie](https://github.com/pnowosie))
- fix: allow processing exits when they were immediately challenged [\#508](https://github.com/omisego/elixir-omg/pull/508) ([pdobacz](https://github.com/pdobacz))
- Omg 418 fee not covered when fee=0 and tx doesnt transfer any fee friendly token [\#507](https://github.com/omisego/elixir-omg/pull/507) ([pthomalla](https://github.com/pthomalla))
- refactor: make in-flight exit unit test behavioral [\#505](https://github.com/omisego/elixir-omg/pull/505) ([pgebal](https://github.com/pgebal))
- feature: observe the size of the mailbox of the processes [\#504](https://github.com/omisego/elixir-omg/pull/504) ([InoMurko](https://github.com/InoMurko))
- fix: fix reporting unavailable piggyback as available [\#503](https://github.com/omisego/elixir-omg/pull/503) ([pgebal](https://github.com/pgebal))
- fix: move slow tests to integration and capture exit logs [\#502](https://github.com/omisego/elixir-omg/pull/502) ([InoMurko](https://github.com/InoMurko))
- OMG-378 feat: allow challenging SEs with IFE txs [\#501](https://github.com/omisego/elixir-omg/pull/501) ([pdobacz](https://github.com/pdobacz))
- Add support for Parity [\#500](https://github.com/omisego/elixir-omg/pull/500) ([paulperegud](https://github.com/paulperegud))
- OMG-211 transaction create endpoint [\#499](https://github.com/omisego/elixir-omg/pull/499) ([pnowosie](https://github.com/pnowosie))
- fix: prefer more frequent and smaller queries for events [\#498](https://github.com/omisego/elixir-omg/pull/498) ([pdobacz](https://github.com/pdobacz))
- chore: gas price change only, when try to push blocks [\#491](https://github.com/omisego/elixir-omg/pull/491) ([pthomalla](https://github.com/pthomalla))
- Omg 381 test in flight and standard exits [\#488](https://github.com/omisego/elixir-omg/pull/488) ([pgebal](https://github.com/pgebal))
- refactor: alter restart strategy [\#472](https://github.com/omisego/elixir-omg/pull/472) ([InoMurko](https://github.com/InoMurko))
- Omg 420 fix "tx seen in blocks at" issue [\#464](https://github.com/omisego/elixir-omg/pull/464) ([pdobacz](https://github.com/pdobacz))

## [v0.1.2](https://github.com/omisego/elixir-omg/tree/v0.1.2) (2019-03-07)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.1...v0.1.2)

**Closed issues:**

- status.get breaks if geth is syncing [\#458](https://github.com/omisego/elixir-omg/issues/458)
- Protocol.UndefinedError - enumerating sth in transaction.submit? [\#457](https://github.com/omisego/elixir-omg/issues/457)
- Writes of deposits/exits to WatcherDB not idempotent [\#454](https://github.com/omisego/elixir-omg/issues/454)
- Watcher does not run in MIX\_ENV=prod mode [\#449](https://github.com/omisego/elixir-omg/issues/449)
- Setry causing exception during error handling [\#437](https://github.com/omisego/elixir-omg/issues/437)

**Merged pull requests:**

- fix: omg watcher and api should have status as a umbrella dependency [\#490](https://github.com/omisego/elixir-omg/pull/490) ([InoMurko](https://github.com/InoMurko))
- feature: gather VM metrics and forward to AppSignal [\#487](https://github.com/omisego/elixir-omg/pull/487) ([InoMurko](https://github.com/InoMurko))
- chore: upgrade MerkleTree [\#486](https://github.com/omisego/elixir-omg/pull/486) ([pthomalla](https://github.com/pthomalla))
- update plasma-contracts version [\#485](https://github.com/omisego/elixir-omg/pull/485) ([pik694](https://github.com/pik694))
- fix: fix demos, make default gas/gasprice more affordable in OMG.Eth [\#484](https://github.com/omisego/elixir-omg/pull/484) ([pdobacz](https://github.com/pdobacz))
- fix: allow Watcher to sync to `staging` which has exits [\#483](https://github.com/omisego/elixir-omg/pull/483) ([pdobacz](https://github.com/pdobacz))
- fix: ignore exit finalized watcher events [\#482](https://github.com/omisego/elixir-omg/pull/482) ([pgebal](https://github.com/pgebal))
- chore: Update CircleCI config for v0.1 [\#481](https://github.com/omisego/elixir-omg/pull/481) ([jbunce](https://github.com/jbunce))
- chore: Bump excoveralls to stop build failure conditions [\#478](https://github.com/omisego/elixir-omg/pull/478) ([jbunce](https://github.com/jbunce))
- fix: make appsignal report metrics [\#477](https://github.com/omisego/elixir-omg/pull/477) ([InoMurko](https://github.com/InoMurko))
- add more granual error handling to transaction reconstruct [\#475](https://github.com/omisego/elixir-omg/pull/475) ([pthomalla](https://github.com/pthomalla))
- Idempotent writes of deposits and exits to WatcherDB \(postgres\) [\#474](https://github.com/omisego/elixir-omg/pull/474) ([pnowosie](https://github.com/pnowosie))
- concurrent jobs [\#473](https://github.com/omisego/elixir-omg/pull/473) ([InoMurko](https://github.com/InoMurko))
- Omg 313 invalid piggybacks, second attempt [\#471](https://github.com/omisego/elixir-omg/pull/471) ([paulperegud](https://github.com/paulperegud))
- fix: Geth.syncing? return boolean [\#470](https://github.com/omisego/elixir-omg/pull/470) ([pthomalla](https://github.com/pthomalla))
- Feat: Add CircleCI config to branch v0.1 [\#469](https://github.com/omisego/elixir-omg/pull/469) ([jbunce](https://github.com/jbunce))
- Fix: Do not deploy the Watcher until the Childchain is in a "Running" status [\#468](https://github.com/omisego/elixir-omg/pull/468) ([jbunce](https://github.com/jbunce))
- Revert "Merge pull request \#422 from omisego/OMG-313-invalid-piggybac… [\#465](https://github.com/omisego/elixir-omg/pull/465) ([paulperegud](https://github.com/paulperegud))
- Omg 437 sentry crashes [\#463](https://github.com/omisego/elixir-omg/pull/463) ([pnowosie](https://github.com/pnowosie))
- feat: Modifies CD to support staging and development environments [\#462](https://github.com/omisego/elixir-omg/pull/462) ([jbunce](https://github.com/jbunce))
- refactor: eth\_height is delivered in BlockApplication now... [\#460](https://github.com/omisego/elixir-omg/pull/460) ([pdobacz](https://github.com/pdobacz))
- OMG-239 fix: adjust multiple configuration parameters to match Ari/staging needs [\#456](https://github.com/omisego/elixir-omg/pull/456) ([pdobacz](https://github.com/pdobacz))
- fix: Check data\_watcher path for chain data [\#455](https://github.com/omisego/elixir-omg/pull/455) ([jbunce](https://github.com/jbunce))
- feat: optional metadata [\#445](https://github.com/omisego/elixir-omg/pull/445) ([pthomalla](https://github.com/pthomalla))
- OMG-313 invalid piggybacks detect and notify [\#422](https://github.com/omisego/elixir-omg/pull/422) ([paulperegud](https://github.com/paulperegud))

## [v0.1.1](https://github.com/omisego/elixir-omg/tree/v0.1.1) (2019-02-21)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.1.0...v0.1.1)

**Closed issues:**

- Exiting utxos show up in the `get\_utxos` result [\#432](https://github.com/omisego/elixir-omg/issues/432)
- Watcher sees unchallenged\_exit exits  [\#430](https://github.com/omisego/elixir-omg/issues/430)
- invalid json requests grill the http-rpc APIs [\#416](https://github.com/omisego/elixir-omg/issues/416)
- Watcher isn't Watching so no UTXO data is returned [\#414](https://github.com/omisego/elixir-omg/issues/414)
- Exception on Watcher startup [\#393](https://github.com/omisego/elixir-omg/issues/393)

**Merged pull requests:**

- Omg 357 move create from utxo to test helper [\#452](https://github.com/omisego/elixir-omg/pull/452) ([purbanow](https://github.com/purbanow))
- feat: Preserve data on Watcher redeploy [\#450](https://github.com/omisego/elixir-omg/pull/450) ([jbunce](https://github.com/jbunce))
- Omg 329 exit proc persistence test [\#448](https://github.com/omisego/elixir-omg/pull/448) ([pdobacz](https://github.com/pdobacz))
- docs: clean API sections in README.md, update TOC [\#447](https://github.com/omisego/elixir-omg/pull/447) ([pdobacz](https://github.com/pdobacz))
- Omg 405 revamp root chain coord [\#444](https://github.com/omisego/elixir-omg/pull/444) ([pdobacz](https://github.com/pdobacz))
- Omg 397 minimal transaction submit for watcher [\#443](https://github.com/omisego/elixir-omg/pull/443) ([pnowosie](https://github.com/pnowosie))
- feat: Add support for custom exit times in docker-compose [\#442](https://github.com/omisego/elixir-omg/pull/442) ([jbunce](https://github.com/jbunce))
- Fix endpoint name in swagger [\#441](https://github.com/omisego/elixir-omg/pull/441) ([jarindr](https://github.com/jarindr))
- fix: demo\_02, demo\_04, update mix.lock [\#440](https://github.com/omisego/elixir-omg/pull/440) ([pthomalla](https://github.com/pthomalla))
- Temp/perftest 20190211 [\#439](https://github.com/omisego/elixir-omg/pull/439) ([pnowosie](https://github.com/pnowosie))
- OMG-395 - \[github\] invalid json requests grill the http-rpc APIs  [\#438](https://github.com/omisego/elixir-omg/pull/438) ([pnowosie](https://github.com/pnowosie))
- Omg 242 metadata field in the transaction [\#435](https://github.com/omisego/elixir-omg/pull/435) ([pthomalla](https://github.com/pthomalla))
- OMG-391 transactions merge utxos are fee free [\#433](https://github.com/omisego/elixir-omg/pull/433) ([pnowosie](https://github.com/pnowosie))

## [v0.1.0](https://github.com/omisego/elixir-omg/tree/v0.1.0) (2019-02-11)
[Full Changelog](https://github.com/omisego/elixir-omg/compare/v0.0.1...v0.1.0)

**Closed issues:**

- New Challenger cannot challenge invalid exits from deposits [\#358](https://github.com/omisego/elixir-omg/issues/358)
- `:unchallenged\_exits` are unchallengable [\#357](https://github.com/omisego/elixir-omg/issues/357)
- Endpoints of the child chain server start too early [\#356](https://github.com/omisego/elixir-omg/issues/356)
- \[elixir-omg\] Watcher fails with unchallenged\_exit [\#347](https://github.com/omisego/elixir-omg/issues/347)
- Cannot create an authority address [\#332](https://github.com/omisego/elixir-omg/issues/332)
- Watcher does not apply blocks [\#284](https://github.com/omisego/elixir-omg/issues/284)
- Watcher API responses redefinition [\#266](https://github.com/omisego/elixir-omg/issues/266)
- Arbitrary Data Transaction Field [\#192](https://github.com/omisego/elixir-omg/issues/192)
- Watcher returns 500 Internal Server Error from /utxos if given an invalid address [\#188](https://github.com/omisego/elixir-omg/issues/188)
- Problem with Browser interaction with Childchain and Watcher due to CORS issue [\#156](https://github.com/omisego/elixir-omg/issues/156)

**Merged pull requests:**

- OMG-405 fix: workaround by removing optional & broken stop on unchallenged\_exit [\#431](https://github.com/omisego/elixir-omg/pull/431) ([pdobacz](https://github.com/pdobacz))
- chore: Bump ethereumex to 0.5.3 [\#429](https://github.com/omisego/elixir-omg/pull/429) ([jbunce](https://github.com/jbunce))
- Omg 386 fix ethlistener corrupt state [\#427](https://github.com/omisego/elixir-omg/pull/427) ([pdobacz](https://github.com/pdobacz))
- test: expand ExitProcessor tests a bit [\#425](https://github.com/omisego/elixir-omg/pull/425) ([pdobacz](https://github.com/pdobacz))
- feat: set custom exit period [\#424](https://github.com/omisego/elixir-omg/pull/424) ([pgebal](https://github.com/pgebal))
- OMG-391 change fee mechanics to match requirements [\#423](https://github.com/omisego/elixir-omg/pull/423) ([pnowosie](https://github.com/pnowosie))
- chore: update phoenix to 1.4, plug to 1.7 and others [\#421](https://github.com/omisego/elixir-omg/pull/421) ([pdobacz](https://github.com/pdobacz))
- Omg 369 challenge the unchallengable [\#420](https://github.com/omisego/elixir-omg/pull/420) ([pdobacz](https://github.com/pdobacz))
- fix: Kill master git ff [\#419](https://github.com/omisego/elixir-omg/pull/419) ([jbunce](https://github.com/jbunce))
- fix: Dont run master merge on master merge [\#418](https://github.com/omisego/elixir-omg/pull/418) ([jbunce](https://github.com/jbunce))
- feat: Test master merge in CI [\#417](https://github.com/omisego/elixir-omg/pull/417) ([jbunce](https://github.com/jbunce))
- Omg 379 move integration assertions to omg api [\#415](https://github.com/omisego/elixir-omg/pull/415) ([pnowosie](https://github.com/pnowosie))
- Fix block getting flakiness and other [\#413](https://github.com/omisego/elixir-omg/pull/413) ([pdobacz](https://github.com/pdobacz))
- Exception on watcher startup [\#412](https://github.com/omisego/elixir-omg/pull/412) ([pthomalla](https://github.com/pthomalla))
- Omg 373 go elixir 1 8 [\#411](https://github.com/omisego/elixir-omg/pull/411) ([pthomalla](https://github.com/pthomalla))
- feat: return the list of open IFEs in status [\#410](https://github.com/omisego/elixir-omg/pull/410) ([pdobacz](https://github.com/pdobacz))
- OMG-356 chore: update ethereumex dependency [\#409](https://github.com/omisego/elixir-omg/pull/409) ([pgebal](https://github.com/pgebal))
- fix: use the contracts with shorter hard-coded exit periods [\#408](https://github.com/omisego/elixir-omg/pull/408) ([pdobacz](https://github.com/pdobacz))
- feat: Remove Elixir 1.6 from CI tests [\#406](https://github.com/omisego/elixir-omg/pull/406) ([jbunce](https://github.com/jbunce))
- Update README to use docker-compose method [\#405](https://github.com/omisego/elixir-omg/pull/405) ([jbunce](https://github.com/jbunce))
- fix: Increase number of retries to allow service to start up [\#404](https://github.com/omisego/elixir-omg/pull/404) ([jbunce](https://github.com/jbunce))
- style: change naming convention in order to stick to the contract [\#403](https://github.com/omisego/elixir-omg/pull/403) ([pik694](https://github.com/pik694))
- fix: Fix docker-compose for Linux [\#402](https://github.com/omisego/elixir-omg/pull/402) ([jbunce](https://github.com/jbunce))
- feat: Add support for Elixir 1.8 CI [\#400](https://github.com/omisego/elixir-omg/pull/400) ([jbunce](https://github.com/jbunce))
- feat: More tidying of CI test image [\#399](https://github.com/omisego/elixir-omg/pull/399) ([jbunce](https://github.com/jbunce))
- test: enrich and unbrittle Persistence tests of State.Core [\#398](https://github.com/omisego/elixir-omg/pull/398) ([pdobacz](https://github.com/pdobacz))
- fix: Move AppSignal loggers to correct location for dev and prod [\#397](https://github.com/omisego/elixir-omg/pull/397) ([jbunce](https://github.com/jbunce))
- chore: Use simplified CircleCI testing image [\#396](https://github.com/omisego/elixir-omg/pull/396) ([jbunce](https://github.com/jbunce))
- feat: Get Ecto telemetry into AppSignal [\#395](https://github.com/omisego/elixir-omg/pull/395) ([jbunce](https://github.com/jbunce))
- Omg 368 child chain endpoints start too early [\#394](https://github.com/omisego/elixir-omg/pull/394) ([pgebal](https://github.com/pgebal))
- Omg 374 new swagger documentation [\#392](https://github.com/omisego/elixir-omg/pull/392) ([pnowosie](https://github.com/pnowosie))
- Omg 310 notify about ifes that involve my address [\#391](https://github.com/omisego/elixir-omg/pull/391) ([purbanow](https://github.com/purbanow))
- feat: upgrade elixir 1.8 and erlang 21.2.3 [\#390](https://github.com/omisego/elixir-omg/pull/390) ([pthomalla](https://github.com/pthomalla))
- Multiple TODOs handled vol.1 [\#389](https://github.com/omisego/elixir-omg/pull/389) ([pdobacz](https://github.com/pdobacz))
- Fix docker-compose.yml watcher env \(again\) [\#388](https://github.com/omisego/elixir-omg/pull/388) ([kevsul](https://github.com/kevsul))
- fix: Change override for non-Mac deploys [\#387](https://github.com/omisego/elixir-omg/pull/387) ([jbunce](https://github.com/jbunce))
- fix: Childchain healthcheck timeout [\#386](https://github.com/omisego/elixir-omg/pull/386) ([jbunce](https://github.com/jbunce))
- fix: Increase childchain healthcheck timeout & fix geth [\#385](https://github.com/omisego/elixir-omg/pull/385) ([jbunce](https://github.com/jbunce))
- Docker compose healthchecks [\#384](https://github.com/omisego/elixir-omg/pull/384) ([jbunce](https://github.com/jbunce))
- fix: Whoops [\#383](https://github.com/omisego/elixir-omg/pull/383) ([jbunce](https://github.com/jbunce))
- feat: Allow contract details for config.exs to be set via an ENV [\#382](https://github.com/omisego/elixir-omg/pull/382) ([jbunce](https://github.com/jbunce))
- refactor: move all private-key related Crypto to DevCrypto [\#381](https://github.com/omisego/elixir-omg/pull/381) ([pdobacz](https://github.com/pdobacz))
- Omg 371 fix discrepancies between api reference and elixir omg [\#380](https://github.com/omisego/elixir-omg/pull/380) ([pgebal](https://github.com/pgebal))
- refactor: move our Mix.Tasks into an umbrella sub app for DRYing [\#379](https://github.com/omisego/elixir-omg/pull/379) ([pdobacz](https://github.com/pdobacz))
- fix: allow BlockGetter to work on 1-scheduler machines [\#378](https://github.com/omisego/elixir-omg/pull/378) ([pdobacz](https://github.com/pdobacz))
- refactor: tweak DeferredConfig for omg\_rpc - populate explicitly [\#377](https://github.com/omisego/elixir-omg/pull/377) ([pdobacz](https://github.com/pdobacz))
- chore: Goodbye Uncle Jenkins [\#376](https://github.com/omisego/elixir-omg/pull/376) ([jbunce](https://github.com/jbunce))
- Omg 353 fix wasteful querries to geths logs and unblock syncs [\#375](https://github.com/omisego/elixir-omg/pull/375) ([pthomalla](https://github.com/pthomalla))
- Fix: Pass CHILDCHAIN\_URL env to watcher in docker-compose [\#374](https://github.com/omisego/elixir-omg/pull/374) ([kevsul](https://github.com/kevsul))
- feat: enable CORS, configurable, enabled by default [\#373](https://github.com/omisego/elixir-omg/pull/373) ([pnowosie](https://github.com/pnowosie))
- Omg 329 cleanup state core test [\#372](https://github.com/omisego/elixir-omg/pull/372) ([pdobacz](https://github.com/pdobacz))
- test: bring back capture\_log to decrease red in test and assert [\#371](https://github.com/omisego/elixir-omg/pull/371) ([pdobacz](https://github.com/pdobacz))
- chore: Bump AppSignal to 1.9 [\#370](https://github.com/omisego/elixir-omg/pull/370) ([jbunce](https://github.com/jbunce))
- Omg 312 Challenging non-canonical IFEs using block txs [\#369](https://github.com/omisego/elixir-omg/pull/369) ([pdobacz](https://github.com/pdobacz))
- OMG-304 use DeferredConfig instead of a custom solution [\#368](https://github.com/omisego/elixir-omg/pull/368) ([pgebal](https://github.com/pgebal))
- fix: Add AppSignal to extra\_applications [\#367](https://github.com/omisego/elixir-omg/pull/367) ([jbunce](https://github.com/jbunce))
- fix: Add Sentry to Watcher's Phoenix endpoint [\#365](https://github.com/omisego/elixir-omg/pull/365) ([jbunce](https://github.com/jbunce))
- feat: add sleep period between deployments of the Childchain & Watcher [\#364](https://github.com/omisego/elixir-omg/pull/364) ([jbunce](https://github.com/jbunce))
- Omg 370 challenge from deposit [\#363](https://github.com/omisego/elixir-omg/pull/363) ([pdobacz](https://github.com/pdobacz))
- Fix blockgetter problem with dont stopping after detecting unchallenged exit [\#362](https://github.com/omisego/elixir-omg/pull/362) ([purbanow](https://github.com/purbanow))
- omg 312 watcher track ife [\#361](https://github.com/omisego/elixir-omg/pull/361) ([pdobacz](https://github.com/pdobacz))
- OMG-259: API request validation [\#360](https://github.com/omisego/elixir-omg/pull/360) ([pnowosie](https://github.com/pnowosie))
- OMG-359\_switch\_from\_push\_system\_to\_pull\_system\_for\_byzantine\_events\_2 [\#359](https://github.com/omisego/elixir-omg/pull/359) ([purbanow](https://github.com/purbanow))
- \[WIP\] Omg 312 integration test competitors are detected [\#354](https://github.com/omisego/elixir-omg/pull/354) ([paulperegud](https://github.com/paulperegud))
- fix: make decoding transaction fail when signatures do not have a proper length [\#353](https://github.com/omisego/elixir-omg/pull/353) ([pgebal](https://github.com/pgebal))
- Omg 300 chain operator minimally conforms to more vp [\#352](https://github.com/omisego/elixir-omg/pull/352) ([pthomalla](https://github.com/pthomalla))
- OMG-365 handle exits from future utxos when syncing [\#351](https://github.com/omisego/elixir-omg/pull/351) ([pdobacz](https://github.com/pdobacz))
- Omg 359 switch from push system to pull system for byzantine events [\#350](https://github.com/omisego/elixir-omg/pull/350) ([purbanow](https://github.com/purbanow))
- OMG-345 Allow to start ife using tx bytes [\#349](https://github.com/omisego/elixir-omg/pull/349) ([pgebal](https://github.com/pgebal))
- Omg 314 - document interaction between MVP and MoreVP [\#348](https://github.com/omisego/elixir-omg/pull/348) ([paulperegud](https://github.com/paulperegud))
- \[elixir-omg\] Add AppSignal support [\#346](https://github.com/omisego/elixir-omg/pull/346) ([jbunce](https://github.com/jbunce))
- fix: demo\_02 and naming [\#345](https://github.com/omisego/elixir-omg/pull/345) ([pthomalla](https://github.com/pthomalla))
- \[circleci\] Fix mix coveralls.post execution [\#344](https://github.com/omisego/elixir-omg/pull/344) ([jbunce](https://github.com/jbunce))
- \[elixir-omg\] Add Sentry report handler for Watcher application [\#343](https://github.com/omisego/elixir-omg/pull/343) ([jbunce](https://github.com/jbunce))
- Omg 302 adjust watcher api [\#342](https://github.com/omisego/elixir-omg/pull/342) ([pdobacz](https://github.com/pdobacz))
- \[launcher\] Fix Childchain deployments for Rinkeby deploys [\#341](https://github.com/omisego/elixir-omg/pull/341) ([jbunce](https://github.com/jbunce))
- \[circleci\] Add CD for the Watcher service [\#340](https://github.com/omisego/elixir-omg/pull/340) ([jbunce](https://github.com/jbunce))
- \[launcher\] Start the Watcher with a fresh LevelDB & Postgres on launch [\#339](https://github.com/omisego/elixir-omg/pull/339) ([jbunce](https://github.com/jbunce))
- \[launcher\] Fix Watcher config.exs write from pre-deployed contract [\#338](https://github.com/omisego/elixir-omg/pull/338) ([jbunce](https://github.com/jbunce))
- Omg 328 add spend set to omgdb [\#337](https://github.com/omisego/elixir-omg/pull/337) ([pnowosie](https://github.com/pnowosie))
- \[elixir-omg\] Set Childchain URL from ENV [\#336](https://github.com/omisego/elixir-omg/pull/336) ([jbunce](https://github.com/jbunce))
- \[elixir-omg\] Fix Plasma contract commit [\#334](https://github.com/omisego/elixir-omg/pull/334) ([jbunce](https://github.com/jbunce))
- \[docker-compose\] Fix Postgres path for Linux users [\#333](https://github.com/omisego/elixir-omg/pull/333) ([jbunce](https://github.com/jbunce))
- fix cleanbuild by making call to OMG.API dynamic [\#331](https://github.com/omisego/elixir-omg/pull/331) ([pdobacz](https://github.com/pdobacz))
- Leveldb refactor [\#330](https://github.com/omisego/elixir-omg/pull/330) ([pik694](https://github.com/pik694))
- fix: prevent child chain allowing spends from exiting deposit [\#329](https://github.com/omisego/elixir-omg/pull/329) ([pdobacz](https://github.com/pdobacz))
- OMG-355 feat: use PriorityQueueLib for cheaper deployments [\#328](https://github.com/omisego/elixir-omg/pull/328) ([pdobacz](https://github.com/pdobacz))
- chore: update watcher database design document [\#327](https://github.com/omisego/elixir-omg/pull/327) ([pgebal](https://github.com/pgebal))
- Add mix deps.clean to Dockerfile [\#326](https://github.com/omisego/elixir-omg/pull/326) ([kevsul](https://github.com/kevsul))
- \[docker-compose\] Add a Linux docker-compose [\#325](https://github.com/omisego/elixir-omg/pull/325) ([jbunce](https://github.com/jbunce))
- \[docker-compose\] Ewallet dockercompose [\#324](https://github.com/omisego/elixir-omg/pull/324) ([jbunce](https://github.com/jbunce))
- \[docker-compose\] Add Watcher ports [\#323](https://github.com/omisego/elixir-omg/pull/323) ([jbunce](https://github.com/jbunce))
- fix: fix database updates for exit processor [\#321](https://github.com/omisego/elixir-omg/pull/321) ([pgebal](https://github.com/pgebal))
- \[elixir-omg/launcher\] More logic fixes for the Childchain [\#320](https://github.com/omisego/elixir-omg/pull/320) ([jbunce](https://github.com/jbunce))
- \[elixir-omg\] Fix Python PEP8 [\#319](https://github.com/omisego/elixir-omg/pull/319) ([jbunce](https://github.com/jbunce))
- \[elixir-omg/launcher\] Fix Childchain Rinkeby deployment logic [\#318](https://github.com/omisego/elixir-omg/pull/318) ([jbunce](https://github.com/jbunce))
- \[elixir-omg/launcher\] Fix path write problem for pre-deployed contracts & Watcher startup [\#317](https://github.com/omisego/elixir-omg/pull/317) ([jbunce](https://github.com/jbunce))
- \[elxir-omg/launcher\] Fix Childchain launcher for Rinkeby [\#316](https://github.com/omisego/elixir-omg/pull/316) ([jbunce](https://github.com/jbunce))
- \[goodbye travis!\] [\#315](https://github.com/omisego/elixir-omg/pull/315) ([jbunce](https://github.com/jbunce))
- \[circleci\] First pass at a CircleCI config [\#314](https://github.com/omisego/elixir-omg/pull/314) ([jbunce](https://github.com/jbunce))
- \[elixir-omg/docker-compose\] Auto stand services up locally [\#313](https://github.com/omisego/elixir-omg/pull/313) ([jbunce](https://github.com/jbunce))
- \[elixir-omg\] Add fix for Sentry [\#312](https://github.com/omisego/elixir-omg/pull/312) ([jbunce](https://github.com/jbunce))
- \[elixir-omg/launcher\] Fix for empty response from exchanger condition [\#311](https://github.com/omisego/elixir-omg/pull/311) ([jbunce](https://github.com/jbunce))
- Omg 334 don't stop validating exits after chain byzantine [\#310](https://github.com/omisego/elixir-omg/pull/310) ([purbanow](https://github.com/purbanow))
- test: fix race condition in happy\_path\_test [\#309](https://github.com/omisego/elixir-omg/pull/309) ([pdobacz](https://github.com/pdobacz))
- Feature/omg 344 morevp compatibility [\#308](https://github.com/omisego/elixir-omg/pull/308) ([pthomalla](https://github.com/pthomalla))
- OMG-355 use solc to do contract compilation \(and reduce deployment gas\) [\#307](https://github.com/omisego/elixir-omg/pull/307) ([pdobacz](https://github.com/pdobacz))
- Omg 305 use prod mix env, don't start\_permanent in :dev anymore [\#306](https://github.com/omisego/elixir-omg/pull/306) ([pdobacz](https://github.com/pdobacz))
- OMG-315 implement consistent api across omg services [\#305](https://github.com/omisego/elixir-omg/pull/305) ([pgebal](https://github.com/pgebal))
- Optimization in WatcherDB [\#304](https://github.com/omisego/elixir-omg/pull/304) ([pnowosie](https://github.com/pnowosie))
- \[elixir-omg\] Fix Watcher database init [\#303](https://github.com/omisego/elixir-omg/pull/303) ([jbunce](https://github.com/jbunce))
- missing mix.lock after dependency added [\#302](https://github.com/omisego/elixir-omg/pull/302) ([pnowosie](https://github.com/pnowosie))
- \[elixir-omg\] Add Ethereum RPC address support to the launcher from ENV [\#301](https://github.com/omisego/elixir-omg/pull/301) ([jbunce](https://github.com/jbunce))
- Omg 230 tidy and tune config [\#298](https://github.com/omisego/elixir-omg/pull/298) ([pdobacz](https://github.com/pdobacz))
- \[elixir-omg\] Add support for getting Ethereum RPC address from an ENV [\#297](https://github.com/omisego/elixir-omg/pull/297) ([jbunce](https://github.com/jbunce))
- Develop [\#296](https://github.com/omisego/elixir-omg/pull/296) ([jbunce](https://github.com/jbunce))
- Develop [\#295](https://github.com/omisego/elixir-omg/pull/295) ([jbunce](https://github.com/jbunce))
- \[elixir-omg\] Add Sentry support for omg\_api [\#294](https://github.com/omisego/elixir-omg/pull/294) ([jbunce](https://github.com/jbunce))
- fix: fix docs, name conventions. Update source consumption list [\#293](https://github.com/omisego/elixir-omg/pull/293) ([pnowosie](https://github.com/pnowosie))
- OMG-346 docs: add known issue of retries/timeouts to morevp.md [\#292](https://github.com/omisego/elixir-omg/pull/292) ([pdobacz](https://github.com/pdobacz))
- \[elixir-omg\] Add support for zero touch Watcher deployments [\#291](https://github.com/omisego/elixir-omg/pull/291) ([jbunce](https://github.com/jbunce))
- fix: fix specification errors [\#290](https://github.com/omisego/elixir-omg/pull/290) ([pgebal](https://github.com/pgebal))
- feat: be more verbose about skipping form\_block and its reasons [\#289](https://github.com/omisego/elixir-omg/pull/289) ([pdobacz](https://github.com/pdobacz))
- HTTP-RPC and swagger for child chain API [\#288](https://github.com/omisego/elixir-omg/pull/288) ([pnowosie](https://github.com/pnowosie))
- docs: update transactions section in Tesuji blockchain design [\#287](https://github.com/omisego/elixir-omg/pull/287) ([pgebal](https://github.com/pgebal))
- fix: update excoveralls dep to fix html output [\#286](https://github.com/omisego/elixir-omg/pull/286) ([pdobacz](https://github.com/pdobacz))
- Update exit\_validation.md [\#285](https://github.com/omisego/elixir-omg/pull/285) ([kevsul](https://github.com/kevsul))
- OMG-308 docs: add the whiteboarded diagram + description [\#283](https://github.com/omisego/elixir-omg/pull/283) ([pdobacz](https://github.com/pdobacz))
- Fix the wrong suffix in the definition of liveness [\#282](https://github.com/omisego/elixir-omg/pull/282) ([nrryuya](https://github.com/nrryuya))
- fix: \neg → \neq in the definition of competing [\#281](https://github.com/omisego/elixir-omg/pull/281) ([nrryuya](https://github.com/nrryuya))
- Add Slate to repo [\#280](https://github.com/omisego/elixir-omg/pull/280) ([kevsul](https://github.com/kevsul))
- \[elixir-omg\] Add support for zero touch Childchain Linux deployments [\#279](https://github.com/omisego/elixir-omg/pull/279) ([jbunce](https://github.com/jbunce))
- feat: support 4 in / 4 out transactions [\#278](https://github.com/omisego/elixir-omg/pull/278) ([pgebal](https://github.com/pgebal))
- Feature/api specs proposal [\#277](https://github.com/omisego/elixir-omg/pull/277) ([kevsul](https://github.com/kevsul))
- Add more APIs [\#276](https://github.com/omisego/elixir-omg/pull/276) ([kevsul](https://github.com/kevsul))
- \[elixir-omg\] Modify Dockerfile to use static binary release of solc [\#275](https://github.com/omisego/elixir-omg/pull/275) ([jbunce](https://github.com/jbunce))
- Feature/omg 326   scripts to run application in different modes [\#274](https://github.com/omisego/elixir-omg/pull/274) ([purbanow](https://github.com/purbanow))
- Feature/omg 327 reorg watcher bug [\#273](https://github.com/omisego/elixir-omg/pull/273) ([pik694](https://github.com/pik694))
- Feature/omg 297 chain operator doesn't submit empty blocks [\#272](https://github.com/omisego/elixir-omg/pull/272) ([purbanow](https://github.com/purbanow))
- OMG-337 fix: add child\_txindex to address\_spent/received events [\#271](https://github.com/omisego/elixir-omg/pull/271) ([pdobacz](https://github.com/pdobacz))
- fix warning about "coveralls" atom [\#269](https://github.com/omisego/elixir-omg/pull/269) ([paulperegud](https://github.com/paulperegud))
- Feature/omg 306 spend on finalization2 [\#268](https://github.com/omisego/elixir-omg/pull/268) ([pdobacz](https://github.com/pdobacz))
- Add rinkeby manual [\#267](https://github.com/omisego/elixir-omg/pull/267) ([pik694](https://github.com/pik694))
- Feature/omg 306 spend on finalization [\#265](https://github.com/omisego/elixir-omg/pull/265) ([pdobacz](https://github.com/pdobacz))
- Unified API proposal [\#264](https://github.com/omisego/elixir-omg/pull/264) ([kevsul](https://github.com/kevsul))
- Feature/deferred config  [\#263](https://github.com/omisego/elixir-omg/pull/263) ([purbanow](https://github.com/purbanow))
- remove test flakiness \(sequence of returend elements\) [\#262](https://github.com/omisego/elixir-omg/pull/262) ([pik694](https://github.com/pik694))
- chore: remove usages of `Supervisor.Spec` [\#259](https://github.com/omisego/elixir-omg/pull/259) ([pik694](https://github.com/pik694))
- Feature/omg 245 run tests on postgres database [\#258](https://github.com/omisego/elixir-omg/pull/258) ([purbanow](https://github.com/purbanow))
- OMG-262 - Improve Watcher integration test - waiting on Eth events [\#257](https://github.com/omisego/elixir-omg/pull/257) ([purbanow](https://github.com/purbanow))
- Fix/stabilize getter state [\#252](https://github.com/omisego/elixir-omg/pull/252) ([pdobacz](https://github.com/pdobacz))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
