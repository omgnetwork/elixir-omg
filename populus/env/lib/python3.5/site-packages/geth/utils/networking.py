import sys
import contextlib
import time
import socket

from .timeout import (
    Timeout,
)


if sys.version_info.major == 2:
    ConnectionRefusedError = socket.timeout


def is_port_open(port):
    sock = socket.socket()
    try:
        sock.bind(('127.0.0.1', port))
    except socket.error:
        return False
    else:
        return True
    finally:
        sock.close()


def get_open_port():
    sock = socket.socket()
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
    sock.close()
    return str(port)


@contextlib.contextmanager
def get_ipc_socket(ipc_path, timeout=0.1):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(ipc_path)
    sock.settimeout(timeout)

    yield sock

    sock.close()


def wait_for_http_connection(port, timeout=5):
    with Timeout(timeout) as _timeout:
        while True:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1)
            try:
                s.connect(('127.0.0.1', port))
            except (socket.timeout, ConnectionRefusedError):
                time.sleep(0.1)
                _timeout.check()
                continue
            else:
                break
        else:
            raise ValueError("Unable to establish HTTP connection")
