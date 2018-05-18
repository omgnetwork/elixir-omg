
import py
from _pytest import runner
import pytest


# copied from xdist remote
def serialize_report(rep):
    import py
    d = rep.__dict__.copy()
    if hasattr(rep.longrepr, 'toterminal'):
        d['longrepr'] = str(rep.longrepr)
    else:
        d['longrepr'] = rep.longrepr
    for name in d:
        if isinstance(d[name], py.path.local):
            d[name] = str(d[name])
        elif name == "result":
            d[name] = None  # for now
    return d


# copied from xdist remote
def unserialize_report(name, reportdict):
    if name == "testreport":
        return runner.TestReport(**reportdict)
    elif name == "collectreport":
        return runner.CollectReport(**reportdict)


def pytest_addoption(parser):
    try:
        __import__('xdist.boxed')
    except ImportError:
        # dont register own option if xdist.boxed is availiable
        group = parser.getgroup("boxed", "boxed subprocess test execution")
        group.addoption(
            '--boxed',
            action="store_true", dest="boxed", default=False,
            help="box each test run in a separate process (unix)")


@pytest.mark.tryfirst
def pytest_runtest_protocol(item):
    if item.config.getvalue("boxed"):
        reports = forked_run_report(item)
        for rep in reports:
            item.ihook.pytest_runtest_logreport(report=rep)
        return True


def forked_run_report(item):
    # for now, we run setup/teardown in the subprocess
    # XXX optionally allow sharing of setup/teardown
    from _pytest.runner import runtestprotocol
    EXITSTATUS_TESTEXIT = 4
    import marshal

    def runforked():
        try:
            reports = runtestprotocol(item, log=False)
        except KeyboardInterrupt:
            py.std.os._exit(EXITSTATUS_TESTEXIT)
        return marshal.dumps([serialize_report(x) for x in reports])

    ff = py.process.ForkedFunc(runforked)
    result = ff.waitfinish()
    if result.retval is not None:
        report_dumps = marshal.loads(result.retval)
        return [unserialize_report("testreport", x) for x in report_dumps]
    else:
        if result.exitstatus == EXITSTATUS_TESTEXIT:
            py.test.exit("forked test item %s raised Exit" % (item,))
        return [report_process_crash(item, result)]


def report_process_crash(item, result):
    path, lineno = item._getfslineno()
    info = ("%s:%s: running the test CRASHED with signal %d" %
            (path, lineno, result.signal))
    from _pytest import runner
    call = runner.CallInfo(lambda: 0/0, "???")
    call.excinfo = info
    rep = runner.pytest_runtest_makereport(item, call)
    if result.out:
        rep.sections.append(("captured stdout", result.out))
    if result.err:
        rep.sections.append(("captured stderr", result.err))
    return rep
