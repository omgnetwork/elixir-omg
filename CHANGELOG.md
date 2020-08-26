# Changelog

## [Unreleased](https://github.com/omgnetwork/elixir-omg/tree/HEAD)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.3...HEAD)

### Enhancements

- Monitoring & alert for pending block submissions [\#1629](https://github.com/omgnetwork/elixir-omg/issues/1629)

### Bug fixes

- exit started ABI decoding call data ROPSTEN [\#1632](https://github.com/omgnetwork/elixir-omg/issues/1632)
- Balance metrics should include deposit utxos [\#1582](https://github.com/omgnetwork/elixir-omg/issues/1582)
- Missing log metadata when json-encoding the log failed [\#1571](https://github.com/omgnetwork/elixir-omg/issues/1571)
- List of lists of signatures borks the endpoint process for `transaction.submit` [\#1158](https://github.com/omgnetwork/elixir-omg/issues/1158)
- Add missing clause on witness validation check [\#1656](https://github.com/omgnetwork/elixir-omg/pull/1656) ([mederic-p](https://github.com/mederic-p))

### Other closed issues

- docker-compose configuration that hooks up to OMG Network V1 Mainnet [\#1694](https://github.com/omgnetwork/elixir-omg/issues/1694)
- Adjustable DB connection pool parameters [\#1684](https://github.com/omgnetwork/elixir-omg/issues/1684)
- Pin elixir and erlang versions for asdf [\#1647](https://github.com/omgnetwork/elixir-omg/issues/1647)
- Handle unexpected HTTP method gracefully [\#1646](https://github.com/omgnetwork/elixir-omg/issues/1646)
- Protocol.UndefinedError: protocol Jason.Encoder not implemented for \#PID\<0.32128.13\> of type PID, Jason.Encoder protocol m... [\#1619](https://github.com/omgnetwork/elixir-omg/issues/1619)
- README warning [\#1581](https://github.com/omgnetwork/elixir-omg/issues/1581)
- StatusCache race condition on startup [\#1557](https://github.com/omgnetwork/elixir-omg/issues/1557)
- docker-compose per each public environment [\#1423](https://github.com/omgnetwork/elixir-omg/issues/1423)
- Ability to filter transactions by date range in transaction.all [\#1417](https://github.com/omgnetwork/elixir-omg/issues/1417)
- Is transaction.submit security critical API? [\#1129](https://github.com/omgnetwork/elixir-omg/issues/1129)
- Queued child chain blocks that got stuck might cause operator to invalidate the child chain [\#702](https://github.com/omgnetwork/elixir-omg/issues/702)
- Finalization of invalid IFEs and invalid IFEs without challenge aren't reported by the Watcher [\#671](https://github.com/omgnetwork/elixir-omg/issues/671)

### Other closed pull requests

- auto trigger chart version bump [\#1695](https://github.com/omgnetwork/elixir-omg/pull/1695) ([boolafish](https://github.com/boolafish))
- Block Validation: New Checks [\#1693](https://github.com/omgnetwork/elixir-omg/pull/1693) ([okalouti](https://github.com/okalouti))
- feat: configurable DB pool size, queue target and queue interval [\#1689](https://github.com/omgnetwork/elixir-omg/pull/1689) ([unnawut](https://github.com/unnawut))
- bump phoenix [\#1680](https://github.com/omgnetwork/elixir-omg/pull/1680) ([InoMurko](https://github.com/InoMurko))
- corrrectly serialize PIDs in alarms.get [\#1678](https://github.com/omgnetwork/elixir-omg/pull/1678) ([ayrat555](https://github.com/ayrat555))
- account.get\_exitable\_utxos is unaware of in-flight exited inputs [\#1676](https://github.com/omgnetwork/elixir-omg/pull/1676) ([pnowosie](https://github.com/pnowosie))
- chore: increase timeouts for childchain healthchecks [\#1671](https://github.com/omgnetwork/elixir-omg/pull/1671) ([ayrat555](https://github.com/ayrat555))
-  /block.validate endpoint [\#1668](https://github.com/omgnetwork/elixir-omg/pull/1668) ([okalouti](https://github.com/okalouti))
- Fix fee adapter to accept decimal value in fee rules [\#1662](https://github.com/omgnetwork/elixir-omg/pull/1662) ([jarindr](https://github.com/jarindr))
- docs: extend description of running cabbage tests [\#1658](https://github.com/omgnetwork/elixir-omg/pull/1658) ([pnowosie](https://github.com/pnowosie))
- fix integration tests [\#1654](https://github.com/omgnetwork/elixir-omg/pull/1654) ([ayrat555](https://github.com/ayrat555))
- fix: unexpected http method [\#1651](https://github.com/omgnetwork/elixir-omg/pull/1651) ([ripzery](https://github.com/ripzery))
- feat: block queue metrics and stalled submission alarm [\#1649](https://github.com/omgnetwork/elixir-omg/pull/1649) ([unnawut](https://github.com/unnawut))
- feat: pin elixir and erlang versions for asdf [\#1648](https://github.com/omgnetwork/elixir-omg/pull/1648) ([unnawut](https://github.com/unnawut))
- chore: change log and version file change for v1.0.3 \(\#1638\) [\#1639](https://github.com/omgnetwork/elixir-omg/pull/1639) ([boolafish](https://github.com/boolafish))
- use cabbage tests from a separate repo [\#1636](https://github.com/omgnetwork/elixir-omg/pull/1636) ([ayrat555](https://github.com/ayrat555))
- set OMG.State GenServer timeout to 10s [\#1517](https://github.com/omgnetwork/elixir-omg/pull/1517) ([achiurizo](https://github.com/achiurizo))

## [v1.0.3](https://github.com/omgnetwork/elixir-omg/tree/v1.0.3) (2020-07-09)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.3-pre.2...v1.0.3)

### Other closed pull requests

- remove trace decorator from OMG.WatcherInfo.DB.EthEvent.get/1 [\#1640](https://github.com/omgnetwork/elixir-omg/pull/1640) ([ayrat555](https://github.com/ayrat555))
- chore: change log and version file change for v1.0.3 [\#1638](https://github.com/omgnetwork/elixir-omg/pull/1638) ([boolafish](https://github.com/boolafish))
- get call\_data and rename it [\#1635](https://github.com/omgnetwork/elixir-omg/pull/1635) ([InoMurko](https://github.com/InoMurko))
- sync v1.0.2 back to master [\#1626](https://github.com/omgnetwork/elixir-omg/pull/1626) ([boolafish](https://github.com/boolafish))
- enable margin [\#1622](https://github.com/omgnetwork/elixir-omg/pull/1622) ([InoMurko](https://github.com/InoMurko))
- fix: handle "transaction underpriced" and other unknown server error responses [\#1617](https://github.com/omgnetwork/elixir-omg/pull/1617) ([unnawut](https://github.com/unnawut))
- Update request body swagger [\#1609](https://github.com/omgnetwork/elixir-omg/pull/1609) ([jarindr](https://github.com/jarindr))
- Auto PR with Auto merge for syncing master-v2 [\#1604](https://github.com/omgnetwork/elixir-omg/pull/1604) ([souradeep-das](https://github.com/souradeep-das))
- integrate spandex ecto [\#1602](https://github.com/omgnetwork/elixir-omg/pull/1602) ([ayrat555](https://github.com/ayrat555))
- Revert "explain analyze updates \(\#1569\)" [\#1601](https://github.com/omgnetwork/elixir-omg/pull/1601) ([boolafish](https://github.com/boolafish))
- feat: sync v1.0.1 changes back to master [\#1599](https://github.com/omgnetwork/elixir-omg/pull/1599) ([unnawut](https://github.com/unnawut))
- release artifacts [\#1597](https://github.com/omgnetwork/elixir-omg/pull/1597) ([InoMurko](https://github.com/InoMurko))
- Add Transaction filter by end\_datetime [\#1595](https://github.com/omgnetwork/elixir-omg/pull/1595) ([jarindr](https://github.com/jarindr))
- Add reorged docker compose [\#1579](https://github.com/omgnetwork/elixir-omg/pull/1579) ([ayrat555](https://github.com/ayrat555))
- Kevin/load test erc20 token [\#1577](https://github.com/omgnetwork/elixir-omg/pull/1577) ([kevsul](https://github.com/kevsul))
- Add block processing queue to watcher info [\#1560](https://github.com/omgnetwork/elixir-omg/pull/1560) ([mederic-p](https://github.com/mederic-p))

## [v1.0.2](https://github.com/omgnetwork/elixir-omg/tree/v1.0.2) (2020-06-30)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.2-pre.0...v1.0.2)

### Other closed pull requests

- chore: bump version in VERSION file [\#1613](https://github.com/omgnetwork/elixir-omg/pull/1613) ([boolafish](https://github.com/boolafish))
- docs: v1.0.2 change logs [\#1611](https://github.com/omgnetwork/elixir-omg/pull/1611) ([boolafish](https://github.com/boolafish))
- chore: merge master back to v1.0.2 [\#1606](https://github.com/omgnetwork/elixir-omg/pull/1606) ([boolafish](https://github.com/boolafish))
- async stream + timeout [\#1593](https://github.com/omgnetwork/elixir-omg/pull/1593) ([InoMurko](https://github.com/InoMurko))
- chore: minor fixes [\#1584](https://github.com/omgnetwork/elixir-omg/pull/1584) ([boolafish](https://github.com/boolafish))
- global block get interval [\#1576](https://github.com/omgnetwork/elixir-omg/pull/1576) ([InoMurko](https://github.com/InoMurko))
- explain analyze updates [\#1569](https://github.com/omgnetwork/elixir-omg/pull/1569) ([InoMurko](https://github.com/InoMurko))
- install telemetry handler for authority balance [\#1567](https://github.com/omgnetwork/elixir-omg/pull/1567) ([InoMurko](https://github.com/InoMurko))
- restart strategy [\#1565](https://github.com/omgnetwork/elixir-omg/pull/1565) ([InoMurko](https://github.com/InoMurko))
- Update README.md [\#1564](https://github.com/omgnetwork/elixir-omg/pull/1564) ([InoMurko](https://github.com/InoMurko))
- Sync v1.0.0 [\#1563](https://github.com/omgnetwork/elixir-omg/pull/1563) ([T-Dnzt](https://github.com/T-Dnzt))
- fix: error attempting to log txhash in binary [\#1532](https://github.com/omgnetwork/elixir-omg/pull/1532) ([unnawut](https://github.com/unnawut))
- use fixed version of ex\_abi [\#1519](https://github.com/omgnetwork/elixir-omg/pull/1519) ([ayrat555](https://github.com/ayrat555))

## [v1.0.1](https://github.com/omgnetwork/elixir-omg/tree/v1.0.1) (2020-06-18)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.1-pre.0...v1.0.1)

### Other closed pull requests

- feat: increase ExitProcessor timeouts [\#1592](https://github.com/omgnetwork/elixir-omg/pull/1592) ([InoMurko](https://github.com/InoMurko))

## [v1.0.0](https://github.com/omgnetwork/elixir-omg/tree/v1.0.0) (2020-06-12)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.0-pre.2...v1.0.0)

### Other closed pull requests

- prevent race condition for status cache [\#1558](https://github.com/omgnetwork/elixir-omg/pull/1558) ([InoMurko](https://github.com/InoMurko))
- Changelog for v1.0.0 [\#1556](https://github.com/omgnetwork/elixir-omg/pull/1556) ([T-Dnzt](https://github.com/T-Dnzt))
- Inomurko/reorg block getter [\#1554](https://github.com/omgnetwork/elixir-omg/pull/1554) ([InoMurko](https://github.com/InoMurko))
- add: logging for ethereum tasks [\#1550](https://github.com/omgnetwork/elixir-omg/pull/1550) ([okalouti](https://github.com/okalouti))
- feat: env configurable block\_submit\_max\_gas\_price [\#1548](https://github.com/omgnetwork/elixir-omg/pull/1548) ([unnawut](https://github.com/unnawut))
- cache blocks into ets [\#1547](https://github.com/omgnetwork/elixir-omg/pull/1547) ([InoMurko](https://github.com/InoMurko))
- updating httpoison [\#1542](https://github.com/omgnetwork/elixir-omg/pull/1542) ([InoMurko](https://github.com/InoMurko))
- feat: add event type when consumer is spending utxos [\#1538](https://github.com/omgnetwork/elixir-omg/pull/1538) ([pnowosie](https://github.com/pnowosie))
- use backport ex\_plasma [\#1537](https://github.com/omgnetwork/elixir-omg/pull/1537) ([achiurizo](https://github.com/achiurizo))
- Watcher configs [\#1536](https://github.com/omgnetwork/elixir-omg/pull/1536) ([dmitrydao](https://github.com/dmitrydao))
- cache status get [\#1535](https://github.com/omgnetwork/elixir-omg/pull/1535) ([InoMurko](https://github.com/InoMurko))
- refactor: consistent log message for new events [\#1534](https://github.com/omgnetwork/elixir-omg/pull/1534) ([unnawut](https://github.com/unnawut))
- chore: sync v0.4.8 into master [\#1531](https://github.com/omgnetwork/elixir-omg/pull/1531) ([unnawut](https://github.com/unnawut))
- transaction rewrite, increase pg connection timeout [\#1525](https://github.com/omgnetwork/elixir-omg/pull/1525) ([InoMurko](https://github.com/InoMurko))
- refactor: remove fixture-based start exit test [\#1514](https://github.com/omgnetwork/elixir-omg/pull/1514) ([unnawut](https://github.com/unnawut))
- fix: add Ink's log\_encoding\_error config [\#1512](https://github.com/omgnetwork/elixir-omg/pull/1512) ([unnawut](https://github.com/unnawut))
- Add deposit.all endpoint and fetch eth\_height retroactively [\#1509](https://github.com/omgnetwork/elixir-omg/pull/1509) ([okalouti](https://github.com/okalouti))
- test: watcher's /status.get cabbage test [\#1508](https://github.com/omgnetwork/elixir-omg/pull/1508) ([unnawut](https://github.com/unnawut))
- fix: exclude active exiting utxos from calls to /account.get\_exitable\_utxos [\#1505](https://github.com/omgnetwork/elixir-omg/pull/1505) ([pgebal](https://github.com/pgebal))
- feat: update ink to v1.1 to fix Mix module not found [\#1504](https://github.com/omgnetwork/elixir-omg/pull/1504) ([unnawut](https://github.com/unnawut))
- refactor: move exit info related functions to smaller responsibility module [\#1503](https://github.com/omgnetwork/elixir-omg/pull/1503) ([boolafish](https://github.com/boolafish))
- fix: lint\_version compatibility with bash [\#1502](https://github.com/omgnetwork/elixir-omg/pull/1502) ([unnawut](https://github.com/unnawut))
- Making Child-chain work with fee feed [\#1500](https://github.com/omgnetwork/elixir-omg/pull/1500) ([pnowosie](https://github.com/pnowosie))
- feat: merge latest v0.4 to master [\#1499](https://github.com/omgnetwork/elixir-omg/pull/1499) ([unnawut](https://github.com/unnawut))
- Papa/sec 27 watcher info ife support [\#1496](https://github.com/omgnetwork/elixir-omg/pull/1496) ([pnowosie](https://github.com/pnowosie))
- Add timestamp and scheduled finalisation time to InvalidExit and UnchallengedExit events [\#1495](https://github.com/omgnetwork/elixir-omg/pull/1495) ([okalouti](https://github.com/okalouti))
- feat: make invalid piggyback cause unchallenged exit event when it's close to being finalized [\#1493](https://github.com/omgnetwork/elixir-omg/pull/1493) ([pgebal](https://github.com/pgebal))
- Introduce spending\_txhash in invalid exit events [\#1492](https://github.com/omgnetwork/elixir-omg/pull/1492) ([mederic-p](https://github.com/mederic-p))
- Kevin/load test cleanup [\#1490](https://github.com/omgnetwork/elixir-omg/pull/1490) ([kevsul](https://github.com/kevsul))
- who monitors the monitor [\#1488](https://github.com/omgnetwork/elixir-omg/pull/1488) ([InoMurko](https://github.com/InoMurko))
- fix: MemoryMonitor breaking on OS that does not provide buffered and cached memory data [\#1486](https://github.com/omgnetwork/elixir-omg/pull/1486) ([unnawut](https://github.com/unnawut))
- \[2\] Add root chain transaction hash to InvalidExit and UnchallengedExit events [\#1485](https://github.com/omgnetwork/elixir-omg/pull/1485) ([okalouti](https://github.com/okalouti))
- Revert "Add root chain transaction hash to InvalidExit and UnchallengedExit events" [\#1483](https://github.com/omgnetwork/elixir-omg/pull/1483) ([okalouti](https://github.com/okalouti))
- Add root chain transaction hash to InvalidExit and UnchallengedExit events [\#1479](https://github.com/omgnetwork/elixir-omg/pull/1479) ([okalouti](https://github.com/okalouti))
- refactor: add prerequisites for makefile targets involving docker-compose [\#1476](https://github.com/omgnetwork/elixir-omg/pull/1476) ([pgebal](https://github.com/pgebal))
- feat: system memory monitor that considers buffered and cached memory [\#1474](https://github.com/omgnetwork/elixir-omg/pull/1474) ([unnawut](https://github.com/unnawut))
- Move db storage out of docker containers [\#1473](https://github.com/omgnetwork/elixir-omg/pull/1473) ([kevsul](https://github.com/kevsul))
- Break down incoming events to publish separately [\#1472](https://github.com/omgnetwork/elixir-omg/pull/1472) ([souradeep-das](https://github.com/souradeep-das))
- feat: add child chain metrics for transaction submissions, successes and failures [\#1470](https://github.com/omgnetwork/elixir-omg/pull/1470) ([unnawut](https://github.com/unnawut))
- Input validation enhancements for endpoints [\#1469](https://github.com/omgnetwork/elixir-omg/pull/1469) ([okalouti](https://github.com/okalouti))
- Update README.md [\#1468](https://github.com/omgnetwork/elixir-omg/pull/1468) ([dmitrydao](https://github.com/dmitrydao))
- Update installation instructions [\#1465](https://github.com/omgnetwork/elixir-omg/pull/1465) ([pnowosie](https://github.com/pnowosie))
- Inomurko/macos nightly build fix [\#1464](https://github.com/omgnetwork/elixir-omg/pull/1464) ([InoMurko](https://github.com/InoMurko))
- fix: circleci to return the original start-services result after logging the failure [\#1463](https://github.com/omgnetwork/elixir-omg/pull/1463) ([unnawut](https://github.com/unnawut))
- Update alpine base image in Dockerfiles to v3.11 [\#1450](https://github.com/omgnetwork/elixir-omg/pull/1450) ([arthurk](https://github.com/arthurk))
- account.get\_utxo pagination [\#1436](https://github.com/omgnetwork/elixir-omg/pull/1436) ([jarindr](https://github.com/jarindr))
- Filtering Input Parameters to Childchain/Watcher API depending on HTTP Method [\#1424](https://github.com/omgnetwork/elixir-omg/pull/1424) ([okalouti](https://github.com/okalouti))
- Prevent split/merge creation in /transaction.create [\#1416](https://github.com/omgnetwork/elixir-omg/pull/1416) ([T-Dnzt](https://github.com/T-Dnzt))
- feat: configurable fee specs path from env var [\#1385](https://github.com/omgnetwork/elixir-omg/pull/1385) ([mederic-p](https://github.com/mederic-p))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
