import signal
import time

from .timeout import (
    Timeout,
)


def wait_for_popen(proc, timeout=30):
    try:
        with Timeout(timeout) as _timeout:
            while proc.poll() is None:
                time.sleep(0.1)
                _timeout.check()
    except Timeout:
        pass


def kill_proc(proc):
    try:
        if proc.poll() is None:
            try:
                proc.send_signal(signal.SIGINT)
                wait_for_popen(proc, 30)
            except KeyboardInterrupt:
                print(
                    "Trying to close geth process.  Press Ctrl+C 2 more times "
                    "to force quit"
                )
        if proc.poll() is None:
            try:
                proc.terminate()
                wait_for_popen(proc, 10)
            except KeyboardInterrupt:
                print(
                    "Trying to close geth process.  Press Ctrl+C 1 more times "
                    "to force quit"
                )
        if proc.poll() is None:
            proc.kill()
            wait_for_popen(proc, 2)
    except KeyboardInterrupt:
        proc.kill()


def format_error_message(prefix, command, return_code, stdoutdata, stderrdata):
    lines = [prefix]

    lines.append("Command    : {0}".format(' '.join(command)))
    lines.append("Return Code: {0}".format(return_code))

    if stdoutdata:
        lines.append("stdout:\n`{0}`".format(stdoutdata))
    else:
        lines.append("stdout: N/A")

    if stderrdata:
        lines.append("stderr:\n`{0}`".format(stderrdata))
    else:
        lines.append("stderr: N/A")

    return "\n".join(lines)
