OMG.Utxo.PositionTest
  * test verbose error on too low encoded position (excluded)
  * test encode and decode the utxo position checking (excluded)

OMG.SignatureTest
  * test recovering a public key from correct signed hash (excluded)
  * test returning an error from an invalid hash (excluded)
  * test recovering from generating a signed hash 2 (excluded)
  * test recovering from generating a signed hash 1 (excluded)

OMG.CryptoTest
  * test sha3 library usage, address generation (excluded)
  * test signature compatibility (excluded)
  * test sign, verify (excluded)
  * test digest sign, recover (excluded)

OMG.State.MeasurementCalculationTest
  * test calculate metrics from state (excluded)

OMG.ChildChainRPC.Web.Controller.AlarmTest
  * test if the controller returns the correct result when there's no alarms raised (excluded)

OMG.BlockTest
  * test Block merkle proof smoke test for deposit transactions (excluded)
  * test Block merkle proof smoke test (excluded)

OMG.Status.Metric.DatadogTest
  * test if exiting process/port sends an exit signal to the parent process (excluded)

OMG.ChildChain.FreshBlocks.CoreTest
  * test getting Block (excluded)
  * test slicing oldest to max size cache (excluded)
  * test can push and pop a lot of blocks from queue (excluded)
  * test combines a fresh block with db result (excluded)
  * test empty fresh blocks makes sense (excluded)

OMG.FeesTest
  * test Transaction can dedicate one input for a fee entirely, reducing to tx's outputs currencies is incorrect (excluded)
  * test Transaction which does not transfer any fee currency is object to fees (excluded)
  * test Transactions covers the fee only in one currency accepted by the operator (excluded)
  * test Merge transactions are free of cost merging utxo erases the fee (excluded)
  * test Merge transactions are free of cost merge is single same address transaction (excluded)
  * test Merge transactions are free of cost merge is single currency transaction (excluded)

OMG.ChildChainRPC.Plugs.HealthTest
  * test testing for boot_in_progress alarm if block.get endpoint rejects request because alarms are raised (excluded)
  * test testing for boot_in_progress alarm if block.get endpoint rejects the request because of bad params when alarm is cleared (excluded)
  * test testing for ethereum_client_connection alarm  if block.get endpoint rejects the request because of bad params when alarm is cleared (excluded)
  * test testing for ethereum_client_connection alarm  if block.get endpoint rejects request because alarms are raised (excluded)

OMG.ChildChain.SupTest
  * test syncs services correctly (excluded)

OMG.Watcher.Eventer.CoreTest
  * test notify function generates 2 proper address_received events (excluded)
  * test generates proper exit finalized event (excluded)
  * test prepare_events function generates 1 proper address_received events (excluded)

OMG.EthereumEventListener.CoreTest
  * test if synced requested higher than root chain height (excluded)
  * test max request size respected (excluded)
  * test can get an empty events list when events too fresh (excluded)
  * test always returns correct height to check in (excluded)
  * test will be eager to get more events, even if none are pulled at first. All will be returned (excluded)
  * test works well close to zero (excluded)
  * test can get multiple events from one height (excluded)
  * test restart allows to continue with proper bounds (excluded)
  * test max request size ignored if caller is insiting to get a lot of events (excluded)
  * test doesn't fail when getting events from empty (excluded)
  * test tolerates being asked to sync on height already synced (excluded)
  * test persists/checks in eth_height without margins substracted, and never goes negative (excluded)
  * test produces next ethereum height range to get events from (excluded)
  * test asks until root chain height provided (excluded)
  * test max request size too small (excluded)

OMG.ChildChain.MonitorTest
  * test if a tuple spec child gets started (excluded)
  * test if a tuple spec child gets restarted after alarm is raised (excluded)
  * test if a map spec child gets started (excluded)
  * test if a tuple spec child gets restarted after exit (excluded)
  * test if a map spec child gets restarted after exit (excluded)

OMG.TypedDataHashTest
  * test Compliance with contract code Output is hashed properly (excluded)
  * test Compliance with contract code EIP domain type is encoded correctly (excluded)
  * test Signature compliance with Metamask test #0 (excluded)
  * test Compliance with contract code domain separator is computed correctly (excluded)
  * test Compliance with contract code Metadata is hashed properly (excluded)
  * test Compliance with contract code Transaction type hash is computed correctly (excluded)
  * test Compliance with contract code Structured hash is computed correctly (excluded)
  * test Compliance with contract code Transaction is hashed correctly (excluded)
  * test Compliance with contract code Input type hash is computed correctly (excluded)
  * test Signature compliance with Metamask test #1 (excluded)
  * test Eip-712 types align with encodeType format (excluded)
  * test Signature compliance with Metamask test #2 (excluded)
  * test Compliance with contract code Input is hashed properly (excluded)
  * test Compliance with contract code Output type hash is computed correctly (excluded)

OMG.State.PersistenceTest
  * test spending produces db updates, that will make the state persist (excluded)
  * test persists piggyback related exits (excluded)
  * test spending produces db updates, that will make the state persist, for all inputs (excluded)
  * test persists exiting (excluded)
  * test all utxos get initialized by query result from db (excluded)
  * test persists ife related exits (excluded)
  * test blocks and spends are persisted (excluded)
  * test tx with zero outputs will not be written to DB, but other stuff will! (excluded)
  * test persists_deposits (excluded)

OMG.Utils.HttpRPC.ResponseTest
  * test cleaning response: simple value list (excluded)
  * test decode16: decodes only specified fields (excluded)
  * test cleaning response structure: map of maps (excluded)
  * test cleaning response: remove nested meta keys (excluded)
  * test test sanitization without ecto preloaded cleaning response structure: list of maps when ecto unloaded (excluded)
  * test skiping sanitize for specified keys (excluded)
  * test sanitize alarm types (excluded)
  * test decode16: called with empty map returns empty map (excluded)
  * test decode16: is safe and don't process not hex-encoded values (excluded)
  * test decode16: decodes all up/down/mixed case values (excluded)
  * test cleaning response structure: list of maps (excluded)
  * test test sanitization without ecto preloaded cleaning response: simple value list works without ecto loaded (excluded)

OMG.Utils.HttpRPC.Validator.BaseTest
  * test list and map preprocessing: mapping list elements (excluded)
  * test Basic validation: length, negative (excluded)
  * test Preprocessors: greater, positive (excluded)
  * test Basic validation: map, negative (excluded)
  * test Basic validation: optional, negative (excluded)
  * test list and map preprocessing: validating list elements (excluded)
  * test Basic validation: optional, positive (excluded)
  * test Basic validation: integer, negative (excluded)
  * test Basic validation: map, positive (excluded)
  * test Basic validation: hex, negative (excluded)
  * test list and map preprocessing: unwrapping results list (excluded)
  * test list and map preprocessing: parsing map (excluded)
  * test Basic validation: list, positive (excluded)
  * test Preprocessors: greater, negative (excluded)
  * test positive and non negative integers (excluded)
  * test Basic validation: hex, positive (excluded)
  * test Preprocessors: address should validate both hex value and its length (excluded)
  * test Basic validation: map, missing (excluded)
  * test Basic validation: length, positive (excluded)
  * test Basic validation: list, negative (excluded)
  * test Basic validation: integer, positive (excluded)

OMG.Status.Metric.StatsdMonitorTest
  * test if exiting process/port sends an exit signal to the parent process 2 (excluded)
  * test if exiting process/port sends an exit signal to the parent process (excluded)

OMG.Watcher.ExitProcessor.FinalizationsTest
  * test in-flight exit finalization exits piggybacked transaction outputs (excluded)
  * test in-flight exit finalization fails when unknown in-flight exit is being finalized (excluded)
  * test determining utxos that are exited by finalization fails when exiting an output that is not piggybacked (excluded)
  * test in-flight exit finalization deactivates in-flight exit after all piggybacked outputs are finalized (excluded)
  * test determining utxos that are exited by finalization fails when unknown in-flight exit is being finalized (excluded)
  * test in-flight exit finalization finalizing perserve in flights exits that are not being finalized (excluded)
  * test in-flight exit finalization finalizing multiple times does not change state or produce database updates (excluded)
  * test sanity checks can process empty finalizations (excluded)
  * test in-flight exit finalization fails when exiting an output that is not piggybacked (excluded)
  * test finalization Watcher events doesn't emit exit events when finalizing invalid exits (excluded)
  * test finalization Watcher events emits exit events when finalizing valid exits (excluded)
  * test in-flight exit finalization exits piggybacked transaction inputs (excluded)
  * test determining utxos that are exited by finalization returns utxos that should be spent when exit finalizes (excluded)

OMG.Watcher.ExitProcessor.Core.StateInteractionTest
  * test can work with State to determine valid exits and finalize them (excluded)
  * test can work with State to determine and notify invalid exits (excluded)
  * test handles invalid exit finalization - doesn't forget and causes a byzantine chain report (excluded)
  * test exits of utxos that couldn't have been seen created yet never excite events (excluded)
  * test only asking for spends concerning ifes (excluded)
  * test acts on invalidities reported when exiting utxos in State (excluded)
  * test can work with State to exit utxos from in-flight transactions (excluded)

OMG.WatcherRPC.Web.Controller.AlarmTest
  * test if the controller returns the correct result when there's no alarms raised (excluded)

OMG.Watcher.ExitProcessor.PersistenceTest
  * test persist finalizations with mixed validities (excluded)
  * test persist multiple challenges (excluded)
  * test persist finalizations with all valid (excluded)
  * test persist challenges (excluded)
  * test persist finalizations with all invalid (excluded)
  * test persist started ifes regardless of status (excluded)
  * test persist ife finalizations (excluded)
  * test persist new challenges, responses and piggybacks (excluded)

OMG.Watcher.UtxoExit.CoreTest
  * test compose output exit (excluded)
  * test creating deposit exit (excluded)
  * test getting exit data returns error when there is no deposit (excluded)
  * test getting exit data returns error when there is no utxo (excluded)
  * test return nil when in blknum not in utxos map (excluded)
  * test return utxo when in blknum in utxos map (excluded)

OMG.Watcher.ExitProcessor.CoreTest
  * test active SE/IFE listing (only IFEs for now) challenges don't affect the list of IFEs returned (excluded)
  * test generic sanity checks can process empty new exits, empty in flight exits (excluded)
  * test finding IFE txs in blocks handles well situation when syncing is in progress (excluded)
  * test active SE/IFE listing (only IFEs for now) correct format of getting all ifes (excluded)
  * test handling of spent blknums result asks for the right blocks when all are spent correctly (excluded)
  * test active SE/IFE listing (only IFEs for now) properly processes new in flight exits, returns all of them on request (excluded)
  * test generic sanity checks can start new standard exits one by one or batched (excluded)
  * test handling of spent blknums result asks for the right blocks if some spends are missing (excluded)
  * test handling of spent blknums result asks for blocks just once (excluded)
  * test generic sanity checks empty processor returns no exiting utxo positions (excluded)
  * test finding IFE txs in blocks seeks all IFE txs' inputs spends in blocks (excluded)
  * test finding IFE txs in blocks seeks IFE txs in blocks only if not already found (excluded)
  * test finding IFE txs in blocks seeks IFE txs in blocks, correctly if IFE inputs duplicate (excluded)
  * test active SE/IFE listing (only IFEs for now) reports piggybacked inputs/outputs when getting ifes (excluded)
  * test generic sanity checks new_exits sanity checks (excluded)
  * test generic sanity checks in flight exits sanity checks (excluded)

OMG.Watcher.MonitorTest
<span class="green">  * test if a tuple spec child gets started (24.2ms)</span>
<span class="green">  * test if a tuple spec child gets restarted after alarm is raised (0.1ms)</span>
<span class="green">  * test if a map spec child gets started (0.04ms)</span>
<span class="green">  * test if a tuple spec child gets restarted after exit (21.7ms)</span>
<span class="green">  * test if a map spec child gets restarted after exit (10.6ms)</span>
[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed


OMG.Watcher.BlockGetter.CoreTest
  * test first block to download number is not zero (excluded)
  * test handle_downloaded_block function after maximum_block_withholding_time_ms returns BlockWithholding event (excluded)
  * test apply block with eth_height lower than synced_height (excluded)
  * test get_numbers_of_blocks_to_download does not return blocks that are being downloaded (excluded)
  * test do not download blocks when there are too many downloaded blocks not yet applied (excluded)
  * test returns valid eth range (excluded)
  * test an unapplied block appears in an already synced eth block (due to reorg) (excluded)
  * test after detecting twice same maximum possible potential withholdings get_numbers_of_blocks_to_download don't return this block (excluded)
  * test apply a block that moved forward (excluded)
  * test validate_executions function prevent getter from progressing when invalid block is detected (excluded)
  * test handle_downloaded_block function called twice with PotentialWithholdingReport returns BlockWithholding event (excluded)
  * test prevents applying when started with an unchallenged_exit (excluded)
  * test the blknum is checked against the requested one (excluded)
  * test does not download same blocks twice and respects increasing next block number (excluded)
  * test check error returned by decoding, one of Transaction.Recovered.recover_from checks (excluded)
  * test handle_downloaded_block function called once with PotentialWithholdingReport doesn't return BlockWithholding event, and get_numbers_of_blocks_to_download function returns this block (excluded)
  * test BlockGetter omits submissions of already applied blocks (excluded)
  * test long running applying block scenario (excluded)
  * test move forward even though an applied block appears in submissions (excluded)
  * test decodes and executes tx with different currencies, always with no fee required (excluded)
  * test allows progressing when no unchallenged exits are detected (excluded)
  * test apply a block that moved backward (excluded)
  * test check error returned by decode_block, hash mismatch checks (excluded)
  * test when State is not at the beginning should not init state properly (excluded)
  * test WatcherDB idempotency: prevents older or block with the same blknum as previously consumed (excluded)
  * test get_numbers_of_blocks_to_download function returns number of potential withholding block which then is canceled (excluded)
  * test WatcherDB idempotency: do not hold blocks when not properly initialized or DB empty (excluded)
  * test applying block updates height (excluded)
  * test get numbers of blocks to download (excluded)
  * test decodes block and validates transaction execution (excluded)
  * test downloaded duplicated and unexpected block (excluded)
  * test WatcherDB idempotency: allows newer blocks to get consumed (excluded)
  * test an already applied child chain block appears in a block above synced_height (due to a reorg) (excluded)
  * test get_numbers_of_blocks_to_download function doesn't return next blocks if state doesn't have empty slots left (excluded)
  * test gets continous ranges of blocks to apply (excluded)
  * test maximum_number_of_pending_blocks can't be too low (excluded)
  * test prevents progressing when unchallenged_exit is detected (excluded)
  * test does not validate block with invalid hash (excluded)

OMG.Watcher.SupervisorTest
  * test syncs services correctly (excluded)

OMG.RootChainCoordinator.CoreTest
  * test root chain back off is ignored (excluded)
  * test does not synchronize service that is not allowed (excluded)
  * test waiting only for the finality margin (excluded)
  * test reports synced heights (excluded)
  * test waiting service will wait and progress accordingly (excluded)
  * test updates root chain height (excluded)
  * test waiting when margin of the awaited process should be skipped ahead (excluded)
  * test waiting for multiple (excluded)
  * test synchronizes services (excluded)
  * test waiting only for the finality margin and some service (excluded)
  * test root chain heights reported observe the finality margin, if present (excluded)
  * test behaves well close to zero (excluded)
  * test prevents huge queries to Ethereum client (excluded)
  * test deregisters and registers a service (excluded)

OMG.Watcher.ExitProcessor.CanonicityTest
  * test finds competitors and allows canonicity challenges handle two competitors, when both are non canonical and used to challenge (excluded)
  * test finds competitors and allows canonicity challenges for nonexistent tx doesn't crash (excluded)
  * test finds competitors and allows canonicity challenges a single competitor included in a block, with proof (excluded)
  * test finds competitors and allows canonicity challenges by asking for utxo existence concerning active ifes and standard exits (excluded)
  * test detects the need and allows to respond to canonicity challenges for malformed input txbytes doesn't crash (excluded)
  * test finds competitors and allows canonicity challenges by not asking for spends on no ifes (excluded)
  * test finds competitors and allows canonicity challenges none if IFE is challenged enough already (excluded)
  * test finds competitors and allows canonicity challenges for malformed input txbytes doesn't crash (excluded)
  * test finds competitors and allows canonicity challenges show competitors, if IFE tx is included but not the oldest - distinct blocks (excluded)
  * test finds competitors and allows canonicity challenges each other, if input spent in different ife (excluded)
  * test finds competitors and allows canonicity challenges show competitors, if IFE tx is included but not the oldest (excluded)
  * test finds competitors and allows canonicity challenges none if input spent in _same_ tx in block (excluded)
  * test finds competitors and allows canonicity challenges none if different input spent in some tx from appendix (excluded)
  * test finds competitors and allows canonicity challenges none if input spent in _same_ tx in tx appendix (excluded)
  * test finds competitors and allows canonicity challenges by not asking for utxo existence concerning finalized ifes (excluded)
  * test finds competitors and allows canonicity challenges a competitor being signed on various positions (excluded)
  * test detects the need and allows to respond to canonicity challenges proving canonical for nonexistent tx doesn't crash (excluded)
  * test sanity checks can process empty challenges and responses (excluded)
  * test finds competitors and allows canonicity challenges don't show competitors, if IFE tx is included (excluded)
  * test detects the need and allows to respond to canonicity challenges against a competitor (excluded)
  * test finds competitors and allows canonicity challenges none if different input spent in some tx from block (excluded)
  * test finds competitors and allows canonicity challenges by asking for utxo spends concerning active ifes (excluded)
  * test detects the need and allows to respond to canonicity challenges none if ifes are fresh and canonical by default (excluded)
  * test finds competitors and allows canonicity challenges a competitor that's submitted as challenge to other IFE (excluded)
  * test detects the need and allows to respond to canonicity challenges when there are two transaction inclusions to respond with (excluded)
  * test finds competitors and allows canonicity challenges a competitor having the double-spend on various input indices (excluded)
  * test detects the need and allows to respond to canonicity challenges none if challenge gets responded and ife canonical (excluded)
  * test finds competitors and allows canonicity challenges none if input not yet created during sync (excluded)
  * test finds competitors and allows canonicity challenges handle two competitors, when the younger one already challenged (excluded)
  * test finds competitors and allows canonicity challenges a best competitor, included earliest in a block, regardless of conflicting utxo position (excluded)
  * test finds competitors and allows canonicity challenges by not asking for utxo spends concerning non-active ifes (excluded)
  * test finds competitors and allows canonicity challenges don't show competitors, if IFE tx is included and is the oldest (excluded)
  * test finds competitors and allows canonicity challenges none if input never spent elsewhere (excluded)

OMG.Watcher.ExitProcessor.PiggybackTest
  * test available piggybacks when output is already piggybacked, it is not reported in piggyback available event (excluded)
  * test evaluates correctness of new piggybacks detects multiple double-spends in single IFE, correctly as more piggybacks appear (excluded)
  * test available piggybacks doesn't detect available piggybacks because txs seen in valid block (excluded)
  * test evaluates correctness of new piggybacks detects and proves double-spend of an output, found in a block, various output indices (excluded)
  * test produces challenges for bad piggybacks fail when asked to produce proof for wrong badly encoded tx (excluded)
  * test evaluates correctness of new piggybacks detects no double-spend of an output, if a different output is being spent in block (excluded)
  * test evaluates correctness of new piggybacks detects double-spend of an input, found in IFE (excluded)
  * test produces challenges for bad piggybacks produces single challenge proof on double-spent piggyback input (excluded)
  * test evaluates correctness of new piggybacks no event if output spent but not piggybacked (excluded)
  * test available piggybacks detects available piggyback because tx not seen in valid block, regardless of competitors (excluded)
  * test evaluates correctness of new piggybacks no event if input double-spent but not piggybacked (excluded)
  * test can open and challenge two piggybacks at one call (excluded)
  * test sanity checks can process empty piggybacks and challenges (excluded)
  * test available piggybacks detects multiple available piggybacks, with all the fields (excluded)
  * test evaluates correctness of new piggybacks detects no double-spend of an input, if a different input is being spent in block (excluded)
  * test evaluates correctness of new piggybacks detects double-spend of an output, found in a IFE (excluded)
  * test produces challenges for bad piggybacks fail when asked to produce proof for wrong txhash (excluded)
  * test available piggybacks when ife is finalized, it's outputs are not reported as available for piggyback (excluded)
  * test produces challenges for bad piggybacks fail when asked to produce proof for wrong oindex (excluded)
  * test forgets challenged piggybacks (excluded)
  * test evaluates correctness of new piggybacks detects and proves double-spend of an output, found in a block, various spending input indices (excluded)
  * test produces challenges for bad piggybacks fail when asked to produce proof for illegal oindex (excluded)
  * test available piggybacks detects available piggyback correctly, even if signed multiple times (excluded)
  * test produces challenges for bad piggybacks will fail if asked to produce proof for correct piggyback on output (excluded)
  * test evaluates correctness of new piggybacks detects double-spend of an input, found in a block (excluded)
  * test produces challenges for bad piggybacks will fail if asked to produce proof for wrong output (excluded)
  * test evaluates correctness of new piggybacks does not look into ife_input_spending_blocks_result when it should not (excluded)
  * test available piggybacks transaction without outputs and different input owners (excluded)
  * test evaluates correctness of new piggybacks detects and proves double-spend of an output, found in a block (excluded)
  * test evaluates correctness of new piggybacks proves and proves double-spend of an output, found in a block, for various inclusion positions (excluded)
  * test available piggybacks challenged IFEs emit the same piggybacks as canonical ones (excluded)
  * test sanity checks throwing when unknown piggyback events arrive (excluded)

OMG.State.CoreTest
  * test extract_initial_state function returns error when passed last deposit as :not_found (excluded)
  * test empty blocks emit empty event triggers (excluded)
  * test beginning of block changes when transactions executed and block formed (excluded)
  * test only successful spending emits event trigger (excluded)
  * test Transaction amounts and fees Zero fee is allowed, transaction is processed without cost (excluded)
  * test can't spend when signature order does not match input order (restrictive spender checks) (excluded)
  * test Transaction amounts and fees Inputs exceeds outputs plus fee (excluded)
  * test removed in-flight inputs from available utxo (excluded)
  * test Transaction can have no outputs (excluded)
  * test Getting current block height on empty state (excluded)
  * test depositing produces db updates, that don't leak to next block (excluded)
  * test Output can have a zero value; can't be used as input though (excluded)
  * test Transaction amounts and fees Merge transaction is fee free (excluded)
  * test spending produces db updates, that don't leak to next block (excluded)
  * test spending provides eth_height in event (excluded)
  * test no pending transactions at start (no events, empty block, no db updates) (excluded)
  * test Transaction amounts and fees output currencies must be included in input currencies (excluded)
  * test forming block doesn't unspend (excluded)
  * test extract_initial_state function returns error when passed top block number as :not_found (excluded)
  * test can spend change and merge coins (excluded)
  * test can spend deposits (excluded)
  * test spending emits event trigger (excluded)
  * test Transaction amounts and fees Inputs sums up exactly to outputs plus fee (excluded)
  * test tells if utxo exists (excluded)
  * test spends utxo validly when exiting (excluded)
  * test Output with zero value will not be written to DB (excluded)
  * test all inputs must be authorized to be spent (excluded)
  * test forming block puts all transactions in a block (excluded)
  * test Output with zero value does not change oindex of other outputs (excluded)
  * test can spend after block is formed (excluded)
  * test Transaction amounts and fees amounts from multiple inputs must add up (excluded)
  * test notifies about invalid utxo exiting (excluded)
  * test Does not allow executing transactions with input utxos from the future (excluded)
  * test every spending emits event triggers (excluded)
  * test getting user utxos from utxos_query_result (excluded)
  * test exits utxos given in various forms (excluded)
  * test ignores deposits from blocks not higher than the block with the last previously received deposit (excluded)
  * test can't spend other people's funds (excluded)
  * test can't spend nonexistent (excluded)
  * test no utxos that belong to address within the empty query result (excluded)
  * test Transaction amounts and fees Inputs are not sufficient for outputs plus fee (excluded)
  * test Getting current block height with one formed block (excluded)
  * test deposits emit event triggers, they don't leak into next block (excluded)
  * test removed utxo after piggyback from available utxo (excluded)
  * test notifies about invalid in-flight exit (excluded)
  * test Transaction amounts and fees respects fees for transactions with mixed currencies (excluded)
  * test forming block empty block after a non-empty block (excluded)
  * test Transaction amounts and fees can spend deposits with mixed currencies (excluded)
  * test can spend a batch of deposits (excluded)
  * test can't spend spent (excluded)

OMG.Watcher.ExitProcessor.StandardExitTest
  * test Core.determine_standard_challenge_queries stops immediately, if exit not found (excluded)
  * test Core.check_validity detect old invalid standard exit (excluded)
  * test Core.determine_standard_challenge_queries asks for correct data: tx utxo double spent in an IFE (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent on input various positions (excluded)
  * test Core.check_validity ifes and standard exits don't interfere (excluded)
  * test Core.create_challenge doesn't create challenge: tx utxo not double spent (excluded)
  * test Core.create_challenge creates challenge: deposit utxo double spent outside an IFE (excluded)
  * test Core.check_validity invalid exits that have been witnessed already inactive don't excite events (excluded)
  * test Core.create_challenge creates challenge: deposit utxo double spent in IFE (excluded)
  * test Core.determine_standard_challenge_queries asks for correct data: deposit utxo double spent in IFE (excluded)
  * test Core.determine_exit_txbytes crashes if asked to produce exit txbytes when creating block not found or db response empty (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent in both block and IFE don't interfere (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent outside an IFE (excluded)
  * test Core.check_validity detect invalid standard exit based on ife tx which spends same input (excluded)
  * test Core.determine_exit_txbytes produces valid exit txbytes for exits from deposits (excluded)
  * test Core.check_validity exits of utxos that couldn't have been seen created yet never excite querying the ledger (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent signed_by different signers (excluded)
  * test ifes and standard exits don't interfere if all valid (excluded)
  * test Core.determine_standard_challenge_queries asks for correct data: deposit utxo double spent outside an IFE (excluded)
  * test challenge events can process challenged exits (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent in an IFE (excluded)
  * test challenge events can challenge exits, which are then forgotten completely (excluded)
  * test Core.check_validity detect invalid standard exit based on utxo missing in main ledger (excluded)
  * test Core.determine_standard_challenge_queries asks for correct data: tx utxo double spent outside an IFE (excluded)
  * test Core.create_challenge creates challenge: tx utxo double spent outside an IFE, but there is an unrelated IFE open (excluded)
  * test Core.create_challenge creates challenge: both utxos spent don't interfere (excluded)
  * test Core.determine_exit_txbytes produces valid exit txbytes for exits from txs in child blocks (excluded)

OMG.ChildChain.BlockQueue.CoreTest
  * test Block queue. Requests correct block range on initialization, non-zero finality threshold (excluded)
  * test Block queue. Produced child blocks to form aren't repeated, if none are enqueued (excluded)
  * test Processing submission results from geth everything might be ok (excluded)
  * test Block queue. A new block is emitted ASAP (excluded)
  * test Adjusting gas price Calling with current ethereum height doesn't change the gas params (excluded)
  * test Processing submission results from geth other fatal errors (excluded)
  * test Adjusting gas price Gas price calculation cannot be raised above limit (excluded)
  * test Block queue. Block generation is driven by last enqueued block Ethereum height and if block is empty or not (excluded)
  * test Processing submission results from geth benign reports / warnings from geth (excluded)
  * test Block queue. Produced blocks submission requests have nonces in order (excluded)
  * test Block queue. Recovery will fail if DB is corrupted (excluded)
  * test Block queue. Block is not enqueued when number of enqueued block does not match expected block number (excluded)
  * test Block queue. Will recover if there are blocks in db but none in root chain (excluded)
  * test Block queue. Recovers after restart to proper mined height (excluded)
  * test Block queue. Won't recover if mined hash doesn't match with hash in db (excluded)
  * test Block queue. Recovers after restart and is able to process more blocks (excluded)
  * test Adjusting gas price Gas price is lowered and then raised when ethereum blocks gap gets filled (excluded)
  * test Block queue. Old blocks are removed, but only after finality_threshold (excluded)
  * test Processing submission results from geth real nonce too low error (excluded)
  * test Block queue. Recovers properly for fresh world state (excluded)
  * test Block queue. Ethereum updates and enqueues can go interleaved (excluded)
  * test Processing submission results from geth benign nonce too low error - related to our tx being mined, since the mined blknum advanced (excluded)
  * test Block queue. Won't recover if mined block number doesn't match with db (excluded)
  * test Adjusting gas price Gas price is lowered when ethereum blocks gap isn't filled (excluded)
  * test Processing submission results from geth gas price change only, when try to push blocks (excluded)
  * test Block queue. No submitBlock will be sent until properly initialized (excluded)
  * test Processing submission results from geth gas price doesn't change when ethereum backs off, even if block in queue (excluded)
  * test Block queue. Smoke test (excluded)
  * test Block queue. Requests correct block range on initialization (excluded)
  * test Block queue. Recovers after restart even when only empty blocks were mined (excluded)
  * test Block queue. Recovers after restart and talking to an un-synced geth (excluded)
  * test Processing submission results from geth gas price changes only, when etherum advanses (excluded)
  * test Adjusting gas price Gas price doesn't change if no new blocks are formed, and is lowered the moment there's one (excluded)
  * test Block queue. Produced child block numbers to form are as expected (excluded)
  * test Adjusting gas price Calling with empty state will initailize gas information (excluded)
  * test Adjusting gas price Gas price is raised when ethereum blocks gap is filled (excluded)
  * test Block queue. Ethereum updates can back off and jump independent from enqueues (excluded)
  * test Block queue. Won't recover if is contract is ahead of db (excluded)

OMG.State.TransactionTest
  * test encoding/decoding is done properly transactions with corrupt signatures don't do harm - one of many signatures (excluded)
  * test APIs used by the `OMG.State.exec/1` transaction with 4in/4out is valid (excluded)
  * test formal protocol rules are enforced Decoding transaction with gaps in outputs returns error (excluded)
  * test encoding/decoding is done properly address in encoded transaction malformed (excluded)
  * test APIs used by the `OMG.State.exec/1` using created transaction with one input in child chain (excluded)
  * test stateless validity critical to the ledger is checked transaction must have distinct inputs (excluded)
  * test APIs used by the `OMG.State.exec/1` using created transaction in child chain (excluded)
  * test hashing and metadata field raw transaction hash is invariant (excluded)
  * test encoding/decoding is done properly rlp encoding of a transaction is corrupt (excluded)
  * test APIs used by the `OMG.State.exec/1` recovering spenders: different signers, one output (excluded)
  * test formal protocol rules are enforced Decoding deposit transaction without inputs is successful (excluded)
  * test formal protocol rules are enforced Decoding transaction with gaps in inputs returns error (excluded)
  * test encoding/decoding is done properly Decode raw transaction, a low level encode/decode parity check (excluded)
  * test formal protocol rules are enforced Decoding transaction without outputs is successful (excluded)
  * test formal protocol rules are enforced transactions with superfluous signatures don't do harm (excluded)
  * test APIs used by the `OMG.State.exec/1` create transaction with different number inputs and outputs (excluded)
  * test formal protocol rules are enforced transaction is not allowed to have input and empty sigs (excluded)
  * test encoding/decoding is done properly transactions with corrupt signatures don't do harm - one signature (excluded)
  * test APIs used by the `OMG.State.exec/1` signed transaction is valid in all input zeroing combinations (excluded)
  * test encoding/decoding is done properly decoding malformed signed transaction (excluded)
  * test hashing and metadata field create transaction with metadata (excluded)

OMG.WatcherRPC.Web.Validators.TypedDataSignedTest
  * test parses transaction with metadata from message data (excluded)
  * test parses transaction from message data (excluded)
  * test validates message correctness (excluded)
  * test ensures network domains match (excluded)
  * test parses eip712 domain (excluded)

OMG.WatcherRPC.Web.Controller.TransactionTest
  * test getting multiple transactions returns only and all txs that match the address filtered (excluded)
  * test submitting structural transaction input &amp; sigs count should match (excluded)
  * test creating transaction: Validation empty transaction without payments list is not allowed (excluded)
  * test submitting binary-encoded transaction provides stateless validation (excluded)
  * test getting transaction by id returns up to 4 inputs / 4 outputs (excluded)
  * test getting multiple transactions returns tx from a particular block that contains requested address as the sender (excluded)
  * test creating transaction advice on merge multi token tx (excluded)
  * test creating transaction: Validation metadata should be hex-encoded hash (excluded)
  * test creating transaction total number of outputs exceeds allowed outputs returns custom error (excluded)
  * test creating transaction advice on merge single token tx (excluded)
  * test creating transaction: Validation incorrect payment in payment list (excluded)
  * test getting transaction by id returns error for non exsiting transaction (excluded)
  * test creating transaction allows to pay single token tx (excluded)
  * test transactions pagination pagination is unstable - client libs needs to remove duplicates (excluded)
  * test creating transaction returns typed data in the form of request of typedDataSign (excluded)
  * test transactions pagination returns list of transactions limited by block number (excluded)
  * test getting multiple transactions returns tx that contains requested address as the recipient and not sender (excluded)
  * test getting multiple transactions returns transactions containing metadata (excluded)
  * test transactions pagination limiting all transactions without address filter (excluded)
  * test getting transaction by id verifies all inserted transactions available to get (excluded)
  * test creating transaction does not return txbytes when spend owner is not provided (excluded)
  * test creating transaction allows to pay multi token tx (excluded)
  * test creating transaction: Validation owner should be hex-encoded address (excluded)
  * test getting multiple transactions returns tx without outputs (amount = 0) and contains requested address as sender (excluded)
  * test creating transaction returns appropriate schema (excluded)
  * test creating transaction: Validation too many payments attempted (excluded)
  * test transactions pagination returns list of transactions limited by address (excluded)
  * test creating transaction insufficient funds returns custom error (excluded)
  * test creating transaction: Validation payment should have valid fields (excluded)
  * test submitting binary-encoded transaction handles incorrectly encoded parameter (excluded)
  * test creating transaction: Validation request's fee object is mandatory (excluded)
  * test creating transaction advice on merge does not merge single utxo (excluded)
  * test getting multiple transactions returns tx that contains requested address as the sender and not recipient (excluded)
  * test getting multiple transactions returns tx without inputs and contains requested address as recipient (excluded)
  * test getting multiple transactions returns tx that contains requested address as both sender &amp; recipient is listed once (excluded)
  * test creating transaction: Validation fee should have valid fields (excluded)
  * test getting transaction by id returns transaction in expected format (excluded)
  * test creating transaction transaction without payments that burns funds in fees is correct (excluded)
  * test submitting structural transaction ensures all required fields are passed (excluded)
  * test creating transaction allows to pay other token tx with fee in different currency (excluded)
  * test creating transaction unknown owner returns insufficient funds error (excluded)
  * test getting transaction by id handles improper length of id parameter (excluded)
  * test creating transaction returns correctly formed transaction, identical with the verbose form (excluded)
  * test getting multiple transactions returns multiple transactions in expected format (excluded)
  * test getting multiple transactions returns tx from a particular block (excluded)
  * test getting multiple transactions digests transactions correctly (excluded)

OMG.Watcher.Integration.InFlightExitTest
  * test in-flight exit competitor is detected by watcher and proven with position immediately[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:35:14.147 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test in-flight exit competitor is detected by watcher and proven with position immediately (47729.3ms)</span>
  * test piggyback in flight exit[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:36:02.083 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test piggyback in flight exit (48858.0ms)</span>
  * test invalid in-flight exit challenge is detected by watcher, because it contains no position[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:36:51.086 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test invalid in-flight exit challenge is detected by watcher, because it contains no position (51892.6ms)</span>
  * test finalization of utxo not recognized in state leaves in-flight exit active[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:37:44.101 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span><span class="yellow">2019-08-28 16:39:07.213 [warn] module=OMG.Watcher.ExitProcessor function=collect_invalidities_and_state_db_updates/2 ⋅Invalid in-flight exit finalization: [%{output_index: 5, tx_hash: &lt;&lt;242, 43, 52, 250, 172, 137, 194, 182, 137, 57, 177, 90, 1, 243, 227, 6, 253, 176, 98, 61, 125, 238, 112, 191, 103, 246, 111, 24, 216, 183, 33, 14&gt;&gt;}]⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test finalization of utxo not recognized in state leaves in-flight exit active (108778.7ms)</span>
  * test honest and cooperating users exit in-flight transaction[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:39:32.055 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test honest and cooperating users exit in-flight transaction (109920.8ms)</span>

OMG.WatcherRPC.Web.Controller.AccountTest
  * test utxo from initial blocks are available (excluded)
  * test returns last transactions that involve given address (excluded)
  * test spent deposits are not a part of utxo set (excluded)
  * test standard_exitable account.get_exitable_utxos handles improper type of parameter (excluded)
  * test encoded utxo positions are delivered (excluded)
  * test standard_exitable get_utxos and get_exitable_utxos have the same return format (excluded)
  * test Account balance groups account tokens and provide sum of available funds (excluded)
  * test unspent deposits are a part of utxo set (excluded)
  * test spent utxos are moved to new owner (excluded)
  * test account.get_balance handles improper type of parameter (excluded)
  * test deposits are spent (excluded)
  * test outputs with value zero are not inserted into DB, the other has correct oindex (excluded)
  * test account.get_utxos handles improper type of parameter (excluded)
  * test no utxos are returned for non-existing addresses (excluded)
  * test Account balance for non-existing account responds with empty array (excluded)
  * test standard_exitable no utxos are returned for non-existing addresses (excluded)

OMG.Watcher.Integration.BlockGetterTest
  * test get the blocks from child chain after sending a transaction and start exit[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:41:23.073 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test get the blocks from child chain after sending a transaction and start exit (99774.0ms)</span>
  * test hash of returned block does not match hash submitted to the root chain[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:43:02.055 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test hash of returned block does not match hash submitted to the root chain (17072.2ms)</span>
  * test transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit unchallenged_exit event[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:43:19.104 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit unchallenged_exit event (47830.4ms)</span>
  * test bad transaction with not existing utxo, detected by interactions with State[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:44:08.072 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test bad transaction with not existing utxo, detected by interactions with State (17864.5ms)</span>

OMG.WatcherRPC.Web.Controller.InFlightExitTest
  * test getting in-flight exits returns properly formatted in-flight exit data (excluded)
  * test getting in-flight exits behaves well if input is not found (excluded)
  * test getting in-flight exits responds with error for malformed in-flight transaction bytes (excluded)
  * test getting in-flight exits behaves well if input malformed (excluded)

OMG.WatcherRPC.Web.Controller.UtxoTest
  * test getting exit data returns error when there is no txs in specfic block (excluded)
  * test get_exit_data should return error when there is no txs in specfic block (excluded)
  * test getting exit data returns properly formatted response (excluded)
  * test get_exit_data should return error when there is no tx in specfic block (excluded)
  * test outputs with value zero are not inserted into DB, the other has correct oindex (excluded)
  * test utxo.get_exit_data handles too low utxo position inputs (excluded)
  * test utxo.get_exit_data handles improper type of parameter (excluded)

OMG.Watcher.Integration.InvalidExitTest
  * test exit which is using already spent utxo from transaction and deposit causes to emit invalid_exit event[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:44:26.080 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test exit which is using already spent utxo from transaction and deposit causes to emit invalid_exit event (46806.9ms)</span>
  * test invalid exit is detected after block withholding[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:45:13.099 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span><span class="yellow">2019-08-28 16:45:39.068 [warn] module=OMG.Watcher.BlockGetter function=do_sync/1 ⋅Chain invalid when trying to sync, because of {:error, [%OMG.Watcher.Event.BlockWithholding{blknum: 2000, hash: &lt;&lt;0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0&gt;&gt;, name: :block_withholding}]}, won't try again⋅
</span><span class="yellow">2019-08-28 16:45:39.069 [warn] module=OMG.Watcher.BlockGetter function=do_producer/1 ⋅Chain invalid when trying to download blocks, because of {:error, [%OMG.Watcher.Event.BlockWithholding{blknum: 2000, hash: &lt;&lt;0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0&gt;&gt;, name: :block_withholding}]}, won't try again⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test invalid exit is detected after block withholding (44864.3ms)</span>
  * test transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:45:58.065 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event (42989.5ms)</span>

OMG.WatcherRPC.Web.Controller.ChallengeTest
  * test challenge data is properly formatted (excluded)
  * test challenging non-existent utxo returns error (excluded)
  * test utxo.get_exit_data handles too low utxo position inputs (excluded)
  * test utxo.get_exit_data handles improper type of parameter (excluded)

OMG.WatcherRPC.Web.Controller.EnforceContentPlugTest
  * test Content type header is no longer required (excluded)

OMG.Eth.EthereumClientMonitorTest
  * test that alarms get raised when we kill the connection (excluded)
  * test that we don't overflow the message queue with timers when Eth client needs time to respond (excluded)
  * test that alarm gets raised if there's no ethereum client running and cleared when it's running (excluded)

OMG.WatcherRPC.Web.Controller.StatusTest

OMG.Watcher.Integration.StatusTest
  * test status endpoint returns expected response format[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:46:41.048 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test status endpoint returns expected response format (15644.4ms)</span>

OMG.Watcher.Integration.TransactionSubmitTest
  * test Thin client scenario[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:46:56.008 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test Thin client scenario (38118.2ms)</span>

OMG.WatcherRPC.Web.Controller.FallbackTest
  * test returns error for non existing method (excluded)

OMG.Watcher.Integration.StandardExitTest
  * test exit finalizes[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="yellow">2019-08-28 16:47:34.017 [warn] module=OMG.Watcher.Application function=set_cookie/1 ⋅Cookie not applied.⋅
</span>[os_mon] memory supervisor port (memsup): Erlang has closed

[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

<span class="green">  * test exit finalizes (92612.3ms)</span>

OMG.State.PropTest
  * property OMG.State.Core prope check (excluded)
  * property quick test of property test (excluded)

OMG.Watcher.Integration.TestServerTest
  * test /block.get - successful response is parsed to expected map (excluded)

OMG.Watcher.DB.EthEventTest
  * test insert deposits: creates deposit event and utxo (excluded)
  * test insert deposits: creates deposits and retrieves them by hash (excluded)
  * test Writes of deposits and exits are idempotent (excluded)
  * test insert exits: creates exit event and marks utxo as spent (excluded)

OMG.ChildChain.Integration.HappyPathTest
  * test check that unspent funds can be exited exited with in-flight exits (excluded)
  * test deposit, spend, restart, exit etc works fine (excluded)

OMG.Watcher.DB.TxOutputTest
  * test compose_utxo_exit should return proper proof format (excluded)
  * test compose_utxo_exit should return error when there is no txs in specfic block (excluded)
  * test transaction output schema handles big numbers properly (excluded)
  * test compose_utxo_exit should return error when there is no tx in specfic block (excluded)

OMG.Watcher.DB.BlockTest
  * test initial data preserve blocks in DB (excluded)
  * test transaction belongs to block can retrieve it by association (excluded)
  * test last consumed block returns correct block number (excluded)
  * test last consumed block is not set in empty database (excluded)

OMG.Watcher.DB.TransactionTest
  * test passing constrains out of allowed takes no effect and print a warning (excluded)
  * test gets all transactions from a block (excluded)

OMG.PerformanceTest
  * test Smoke test - run start_simple_perf and see if it don't crash (excluded)
  * test Smoke test - run start_extended_perf and see if it don't crash (excluded)
  * test Smoke test - run start_simple_perf and see if it don't crash - overiding block creation (excluded)
  * test Smoke test - run start_simple_perf and see if it don't crash - with profiling (excluded)

OMG.ChildChain.Integration.FeeServerTest
  * test fees in effect corrupted file does not make server crash (excluded)
  * test fees ignored fee server ignores file updates (excluded)
  * test fees in effect starting with corrupted file makes server die (excluded)

OMG.RocksDBTest
  * test rocks db handles object storage (excluded)
  * test if multi reading utxos returns writen results (excluded)
  * test rocks db handles single value storage (excluded)
  * test if multi reading exit infos returns writen results (excluded)
  * test block hashes return the correct range (excluded)
  * test if multi reading in flight exit infos returns writen results (excluded)
  * test if multi reading and writting does not pollute returned values (excluded)
  * test if multi reading competitor infos returns writen results (excluded)

OMG.DBTest
  * test handles object storage (excluded)
  * test if multi reading utxos returns writen results (excluded)
  * test handles single value storage (excluded)
  * test if multi reading exit infos returns writen results (excluded)
  * test block hashes return the correct range (excluded)
  * test if multi reading in flight exit infos returns writen results (excluded)
  * test if multi reading and writting does not pollute returned values (excluded)
  * test if multi reading competitor infos returns writen results (excluded)

OMG.EthTest
  * test no argument call returning single integer (excluded)
  * test get contract deployment height (excluded)
  * test get_ethereum_height and get_block_timestamp_by_number return integers (excluded)
  * test single binary argument call returning bool (excluded)
  * test gets events with various fields and topics (excluded)
  * test binary/integer arugments tx and integer argument call returning a binary/integer tuple (excluded)

OMG.Watcher.API.AlarmTest
  * test if alarms are returned when there are alarms raised (excluded)
  * test if alarms are returned when there are no alarms raised (excluded)

OMG.StateTest
  * test can execute various calls on OMG.State, one happy path only (excluded)

OMG.RootChainCoordinatorTest
  * test can do a simplest sync (excluded)

OMG.Status.Alert.AlarmTest
  * test raise and clear alarm based on full alarm (excluded)
  * test raise and clear alarm based only on id (excluded)
  * test adds and removes alarms (excluded)
  * test memsup alarms (excluded)
  * test an alarm raise twice is reported once (excluded)

OMG.ChildChainRPC.Web.Controller.BlockTest
  * test block.get endpoint rejects parameters not properly encoded as hex (excluded)
  * test block.get endpoint rejects request without parameter (excluded)
  * test block.get endpoint rejects improper length parameter (excluded)

OMG.Eth.SubscriptionWorkerTest
  * test that worker can subscribe to different events and receive events (excluded)

OMG.DependencyConformance.SignatureTest
  * test signature test empty transaction (excluded)
  * test signature test transaction with metadata (excluded)
  * test signature test (excluded)

OMG.ChildChainRPC.Web.Controller.TransactionTest
  * test transaction.submit endpoint rejects request with non hex transaction (excluded)
  * test transaction.submit endpoint rejects request without parameter (excluded)

OMG.DB.ApplicationTest
  * test starts and stops app, inits (excluded)

OMG.ChildChainRPC.Web.Controller.FallbackTest
  * test returns error for non existing method (excluded)

OMG.ChildChainTest
  * test if alarms are returned when there are alarms raised (excluded)
  * test if alarms are returned when there are no alarms raised (excluded)
