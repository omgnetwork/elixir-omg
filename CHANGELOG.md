# Changelog

## [Unreleased](https://github.com/omgnetwork/elixir-omg/tree/HEAD)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.3...HEAD)

### API changes

-  /block.validate endpoint [\#1668](https://github.com/omgnetwork/elixir-omg/pull/1668) ([okalouti](https://github.com/okalouti))

### Enhancements

- Block Validation: New Checks [\#1693](https://github.com/omgnetwork/elixir-omg/pull/1693) ([okalouti](https://github.com/okalouti))
- feat: configurable DB pool size, queue target and queue interval [\#1689](https://github.com/omgnetwork/elixir-omg/pull/1689) ([unnawut](https://github.com/unnawut))
- feat: block queue metrics and stalled submission alarm [\#1649](https://github.com/omgnetwork/elixir-omg/pull/1649) ([unnawut](https://github.com/unnawut))

### Bug fixes

- corrrectly serialize PIDs in alarms.get [\#1678](https://github.com/omgnetwork/elixir-omg/pull/1678) ([ayrat555](https://github.com/ayrat555))
- account.get\_exitable\_utxos is unaware of in-flight exited inputs [\#1676](https://github.com/omgnetwork/elixir-omg/pull/1676) ([pnowosie](https://github.com/pnowosie))
- Fix fee adapter to accept decimal value in fee rules [\#1662](https://github.com/omgnetwork/elixir-omg/pull/1662) ([jarindr](https://github.com/jarindr))
- Add missing clause on witness validation check [\#1656](https://github.com/omgnetwork/elixir-omg/pull/1656) ([mederic-p](https://github.com/mederic-p))
- fix: unexpected http method [\#1651](https://github.com/omgnetwork/elixir-omg/pull/1651) ([ripzery](https://github.com/ripzery))

### Chores

- auto trigger chart version bump [\#1695](https://github.com/omgnetwork/elixir-omg/pull/1695) ([boolafish](https://github.com/boolafish))
- bump phoenix [\#1680](https://github.com/omgnetwork/elixir-omg/pull/1680) ([InoMurko](https://github.com/InoMurko))
- chore: increase timeouts for childchain healthchecks [\#1671](https://github.com/omgnetwork/elixir-omg/pull/1671) ([ayrat555](https://github.com/ayrat555))
- fix integration tests [\#1654](https://github.com/omgnetwork/elixir-omg/pull/1654) ([ayrat555](https://github.com/ayrat555))
- feat: pin elixir and erlang versions for asdf [\#1648](https://github.com/omgnetwork/elixir-omg/pull/1648) ([unnawut](https://github.com/unnawut))
- chore: change log and version file change for v1.0.3 \(\#1638\) [\#1639](https://github.com/omgnetwork/elixir-omg/pull/1639) ([boolafish](https://github.com/boolafish))
- use cabbage tests from a separate repo [\#1636](https://github.com/omgnetwork/elixir-omg/pull/1636) ([ayrat555](https://github.com/ayrat555))
- set OMG.State GenServer timeout to 10s [\#1517](https://github.com/omgnetwork/elixir-omg/pull/1517) ([achiurizo](https://github.com/achiurizo))

### Documentation updates

- docs: extend description of running cabbage tests [\#1658](https://github.com/omgnetwork/elixir-omg/pull/1658) ([pnowosie](https://github.com/pnowosie))

## [v1.0.3](https://github.com/omgnetwork/elixir-omg/tree/v1.0.3) (2020-07-09)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.3-pre.2...v1.0.3)

### API changes

- Add Transaction filter by end\_datetime [\#1595](https://github.com/omgnetwork/elixir-omg/pull/1595) ([jarindr](https://github.com/jarindr))

### Enhancements

- Add block processing queue to watcher info [\#1560](https://github.com/omgnetwork/elixir-omg/pull/1560) ([mederic-p](https://github.com/mederic-p))

### Bug fixes

- remove trace decorator from OMG.WatcherInfo.DB.EthEvent.get/1 [\#1640](https://github.com/omgnetwork/elixir-omg/pull/1640) ([ayrat555](https://github.com/ayrat555))
- get call\_data and rename it [\#1635](https://github.com/omgnetwork/elixir-omg/pull/1635) ([InoMurko](https://github.com/InoMurko))
- fix: handle "transaction underpriced" and other unknown server error responses [\#1617](https://github.com/omgnetwork/elixir-omg/pull/1617) ([unnawut](https://github.com/unnawut))

### Chores

- chore: change log and version file change for v1.0.3 [\#1638](https://github.com/omgnetwork/elixir-omg/pull/1638) ([boolafish](https://github.com/boolafish))
- sync v1.0.2 back to master [\#1626](https://github.com/omgnetwork/elixir-omg/pull/1626) ([boolafish](https://github.com/boolafish))
- enable margin [\#1622](https://github.com/omgnetwork/elixir-omg/pull/1622) ([InoMurko](https://github.com/InoMurko))
- Auto PR with Auto merge for syncing master-v2 [\#1604](https://github.com/omgnetwork/elixir-omg/pull/1604) ([souradeep-das](https://github.com/souradeep-das))
- integrate spandex ecto [\#1602](https://github.com/omgnetwork/elixir-omg/pull/1602) ([ayrat555](https://github.com/ayrat555))
- Revert "explain analyze updates \(\#1569\)" [\#1601](https://github.com/omgnetwork/elixir-omg/pull/1601) ([boolafish](https://github.com/boolafish))
- feat: sync v1.0.1 changes back to master [\#1599](https://github.com/omgnetwork/elixir-omg/pull/1599) ([unnawut](https://github.com/unnawut))
- release artifacts [\#1597](https://github.com/omgnetwork/elixir-omg/pull/1597) ([InoMurko](https://github.com/InoMurko))
- Add reorged docker compose [\#1579](https://github.com/omgnetwork/elixir-omg/pull/1579) ([ayrat555](https://github.com/ayrat555))
- Kevin/load test erc20 token [\#1577](https://github.com/omgnetwork/elixir-omg/pull/1577) ([kevsul](https://github.com/kevsul))

### Documentation updates

- Update request body swagger [\#1609](https://github.com/omgnetwork/elixir-omg/pull/1609) ([jarindr](https://github.com/jarindr))

## [v1.0.2](https://github.com/omgnetwork/elixir-omg/tree/v1.0.2) (2020-06-30)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.2-pre.0...v1.0.2)

### Enhancements

- global block get interval [\#1576](https://github.com/omgnetwork/elixir-omg/pull/1576) ([InoMurko](https://github.com/InoMurko))
- install telemetry handler for authority balance [\#1567](https://github.com/omgnetwork/elixir-omg/pull/1567) ([InoMurko](https://github.com/InoMurko))
- restart strategy [\#1565](https://github.com/omgnetwork/elixir-omg/pull/1565) ([InoMurko](https://github.com/InoMurko))

### Bug fixes

- async stream + timeout [\#1593](https://github.com/omgnetwork/elixir-omg/pull/1593) ([InoMurko](https://github.com/InoMurko))
- fix: error attempting to log txhash in binary [\#1532](https://github.com/omgnetwork/elixir-omg/pull/1532) ([unnawut](https://github.com/unnawut))
- use fixed version of ex\_abi [\#1519](https://github.com/omgnetwork/elixir-omg/pull/1519) ([ayrat555](https://github.com/ayrat555))

### Chores

- chore: bump version in VERSION file [\#1613](https://github.com/omgnetwork/elixir-omg/pull/1613) ([boolafish](https://github.com/boolafish))
- docs: v1.0.2 change logs [\#1611](https://github.com/omgnetwork/elixir-omg/pull/1611) ([boolafish](https://github.com/boolafish))
- chore: merge master back to v1.0.2 [\#1606](https://github.com/omgnetwork/elixir-omg/pull/1606) ([boolafish](https://github.com/boolafish))
- chore: minor fixes [\#1584](https://github.com/omgnetwork/elixir-omg/pull/1584) ([boolafish](https://github.com/boolafish))
- explain analyze updates [\#1569](https://github.com/omgnetwork/elixir-omg/pull/1569) ([InoMurko](https://github.com/InoMurko))
- Sync v1.0.0 [\#1563](https://github.com/omgnetwork/elixir-omg/pull/1563) ([T-Dnzt](https://github.com/T-Dnzt))

### Documentation updates

- Update README.md [\#1564](https://github.com/omgnetwork/elixir-omg/pull/1564) ([InoMurko](https://github.com/InoMurko))

## [v1.0.1](https://github.com/omgnetwork/elixir-omg/tree/v1.0.1) (2020-06-18)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.1-pre.0...v1.0.1)

### Chores

- feat: increase ExitProcessor timeouts [\#1592](https://github.com/omgnetwork/elixir-omg/pull/1592) ([InoMurko](https://github.com/InoMurko))

## [v1.0.0](https://github.com/omgnetwork/elixir-omg/tree/v1.0.0) (2020-06-12)

[Full Changelog](https://github.com/omgnetwork/elixir-omg/compare/v1.0.0-pre.2...v1.0.0)

### API changes

- Add deposit.all endpoint and fetch eth\_height retroactively [\#1509](https://github.com/omgnetwork/elixir-omg/pull/1509) ([okalouti](https://github.com/okalouti))
- Add timestamp and scheduled finalisation time to InvalidExit and UnchallengedExit events [\#1495](https://github.com/omgnetwork/elixir-omg/pull/1495) ([okalouti](https://github.com/okalouti))
- Introduce spending\_txhash in invalid exit events [\#1492](https://github.com/omgnetwork/elixir-omg/pull/1492) ([mederic-p](https://github.com/mederic-p))
- \[2\] Add root chain transaction hash to InvalidExit and UnchallengedExit events [\#1485](https://github.com/omgnetwork/elixir-omg/pull/1485) ([okalouti](https://github.com/okalouti))
- Add root chain transaction hash to InvalidExit and UnchallengedExit events [\#1479](https://github.com/omgnetwork/elixir-omg/pull/1479) ([okalouti](https://github.com/okalouti))
- Input validation enhancements for endpoints [\#1469](https://github.com/omgnetwork/elixir-omg/pull/1469) ([okalouti](https://github.com/okalouti))
- account.get\_utxo pagination [\#1436](https://github.com/omgnetwork/elixir-omg/pull/1436) ([jarindr](https://github.com/jarindr))
- Filtering Input Parameters to Childchain/Watcher API depending on HTTP Method [\#1424](https://github.com/omgnetwork/elixir-omg/pull/1424) ([okalouti](https://github.com/okalouti))
- Prevent split/merge creation in /transaction.create [\#1416](https://github.com/omgnetwork/elixir-omg/pull/1416) ([T-Dnzt](https://github.com/T-Dnzt))

### Enhancements

- Inomurko/reorg block getter [\#1554](https://github.com/omgnetwork/elixir-omg/pull/1554) ([InoMurko](https://github.com/InoMurko))
- add: logging for ethereum tasks [\#1550](https://github.com/omgnetwork/elixir-omg/pull/1550) ([okalouti](https://github.com/okalouti))
- feat: env configurable block\_submit\_max\_gas\_price [\#1548](https://github.com/omgnetwork/elixir-omg/pull/1548) ([unnawut](https://github.com/unnawut))
- cache blocks into ets [\#1547](https://github.com/omgnetwork/elixir-omg/pull/1547) ([InoMurko](https://github.com/InoMurko))
- feat: add event type when consumer is spending utxos [\#1538](https://github.com/omgnetwork/elixir-omg/pull/1538) ([pnowosie](https://github.com/pnowosie))
- cache status get [\#1535](https://github.com/omgnetwork/elixir-omg/pull/1535) ([InoMurko](https://github.com/InoMurko))
- refactor: consistent log message for new events [\#1534](https://github.com/omgnetwork/elixir-omg/pull/1534) ([unnawut](https://github.com/unnawut))
- transaction rewrite, increase pg connection timeout [\#1525](https://github.com/omgnetwork/elixir-omg/pull/1525) ([InoMurko](https://github.com/InoMurko))
- Making Child-chain work with fee feed [\#1500](https://github.com/omgnetwork/elixir-omg/pull/1500) ([pnowosie](https://github.com/pnowosie))
- Papa/sec 27 watcher info ife support [\#1496](https://github.com/omgnetwork/elixir-omg/pull/1496) ([pnowosie](https://github.com/pnowosie))
- feat: make invalid piggyback cause unchallenged exit event when it's close to being finalized [\#1493](https://github.com/omgnetwork/elixir-omg/pull/1493) ([pgebal](https://github.com/pgebal))
- who monitors the monitor [\#1488](https://github.com/omgnetwork/elixir-omg/pull/1488) ([InoMurko](https://github.com/InoMurko))
- feat: system memory monitor that considers buffered and cached memory [\#1474](https://github.com/omgnetwork/elixir-omg/pull/1474) ([unnawut](https://github.com/unnawut))
- Break down incoming events to publish separately [\#1472](https://github.com/omgnetwork/elixir-omg/pull/1472) ([souradeep-das](https://github.com/souradeep-das))
- feat: add child chain metrics for transaction submissions, successes and failures [\#1470](https://github.com/omgnetwork/elixir-omg/pull/1470) ([unnawut](https://github.com/unnawut))
- feat: configurable fee specs path from env var [\#1385](https://github.com/omgnetwork/elixir-omg/pull/1385) ([mederic-p](https://github.com/mederic-p))

### Bug fixes

- prevent race condition for status cache [\#1558](https://github.com/omgnetwork/elixir-omg/pull/1558) ([InoMurko](https://github.com/InoMurko))
- fix: add Ink's log\_encoding\_error config [\#1512](https://github.com/omgnetwork/elixir-omg/pull/1512) ([unnawut](https://github.com/unnawut))
- fix: exclude active exiting utxos from calls to /account.get\_exitable\_utxos [\#1505](https://github.com/omgnetwork/elixir-omg/pull/1505) ([pgebal](https://github.com/pgebal))
- feat: update ink to v1.1 to fix Mix module not found [\#1504](https://github.com/omgnetwork/elixir-omg/pull/1504) ([unnawut](https://github.com/unnawut))
- fix: MemoryMonitor breaking on OS that does not provide buffered and cached memory data [\#1486](https://github.com/omgnetwork/elixir-omg/pull/1486) ([unnawut](https://github.com/unnawut))

### Chores

- Changelog for v1.0.0 [\#1556](https://github.com/omgnetwork/elixir-omg/pull/1556) ([T-Dnzt](https://github.com/T-Dnzt))
- updating httpoison [\#1542](https://github.com/omgnetwork/elixir-omg/pull/1542) ([InoMurko](https://github.com/InoMurko))
- use backport ex\_plasma [\#1537](https://github.com/omgnetwork/elixir-omg/pull/1537) ([achiurizo](https://github.com/achiurizo))
- chore: sync v0.4.8 into master [\#1531](https://github.com/omgnetwork/elixir-omg/pull/1531) ([unnawut](https://github.com/unnawut))
- refactor: remove fixture-based start exit test [\#1514](https://github.com/omgnetwork/elixir-omg/pull/1514) ([unnawut](https://github.com/unnawut))
- test: watcher's /status.get cabbage test [\#1508](https://github.com/omgnetwork/elixir-omg/pull/1508) ([unnawut](https://github.com/unnawut))
- refactor: move exit info related functions to smaller responsibility module [\#1503](https://github.com/omgnetwork/elixir-omg/pull/1503) ([boolafish](https://github.com/boolafish))
- fix: lint\_version compatibility with bash [\#1502](https://github.com/omgnetwork/elixir-omg/pull/1502) ([unnawut](https://github.com/unnawut))
- feat: merge latest v0.4 to master [\#1499](https://github.com/omgnetwork/elixir-omg/pull/1499) ([unnawut](https://github.com/unnawut))
- Kevin/load test cleanup [\#1490](https://github.com/omgnetwork/elixir-omg/pull/1490) ([kevsul](https://github.com/kevsul))
- Revert "Add root chain transaction hash to InvalidExit and UnchallengedExit events" [\#1483](https://github.com/omgnetwork/elixir-omg/pull/1483) ([okalouti](https://github.com/okalouti))
- refactor: add prerequisites for makefile targets involving docker-compose [\#1476](https://github.com/omgnetwork/elixir-omg/pull/1476) ([pgebal](https://github.com/pgebal))
- Move db storage out of docker containers [\#1473](https://github.com/omgnetwork/elixir-omg/pull/1473) ([kevsul](https://github.com/kevsul))
- Inomurko/macos nightly build fix [\#1464](https://github.com/omgnetwork/elixir-omg/pull/1464) ([InoMurko](https://github.com/InoMurko))
- fix: circleci to return the original start-services result after logging the failure [\#1463](https://github.com/omgnetwork/elixir-omg/pull/1463) ([unnawut](https://github.com/unnawut))
- Update alpine base image in Dockerfiles to v3.11 [\#1450](https://github.com/omgnetwork/elixir-omg/pull/1450) ([arthurk](https://github.com/arthurk))

### Documentation updates

- Watcher configs [\#1536](https://github.com/omgnetwork/elixir-omg/pull/1536) ([dmitrydao](https://github.com/dmitrydao))
- Update README.md [\#1468](https://github.com/omgnetwork/elixir-omg/pull/1468) ([dmitrydao](https://github.com/dmitrydao))
- Update installation instructions [\#1465](https://github.com/omgnetwork/elixir-omg/pull/1465) ([pnowosie](https://github.com/pnowosie))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
