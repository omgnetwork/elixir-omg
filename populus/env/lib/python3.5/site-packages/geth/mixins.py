from __future__ import absolute_import

import datetime
import logging
import os

try:
    import queue
except ImportError:
    # python 2 support
    import Queue as queue

import time

from geth.utils.filesystem import ensure_path_exists
from geth.utils.thread import (
    spawn,
)
from geth.utils.timeout import (
    Timeout,
)


def construct_logger_file_path(prefix, suffix):
    ensure_path_exists('./logs')
    timestamp = datetime.datetime.now().strftime(
        '{prefix}-%Y%m%d-%H%M%S-{suffix}.log'.format(
            prefix=prefix, suffix=suffix,
        ),
    )
    return os.path.join('logs', timestamp)


def get_file_logger(name, filename):
    # create logger with 'spam_application'
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    # create file handler which logs even debug messages
    fh = logging.FileHandler(filename)
    fh.setLevel(logging.DEBUG)
    # create console handler with a higher log level
    ch = logging.StreamHandler()
    ch.setLevel(logging.ERROR)
    # create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    # add the handlers to the logger
    logger.addHandler(fh)
    logger.addHandler(ch)

    return logger


class JoinableQueue(queue.Queue):
    def __iter__(self):
        while True:
            item = self.get()
            if isinstance(item, Exception):
                raise item
            elif isinstance(item, type) and issubclass(item, Exception):
                raise item
            yield item

    def join(self, timeout=None):
        with Timeout(timeout) as _timeout:
            while not self.empty():
                time.sleep(0)
                _timeout.check()


class InterceptedStreamsMixin(object):
    """
    Mixin class for GethProcess instances that feeds all of the stdout and
    stderr lines into some set of provided callback functions.
    """
    stdout_callbacks = None
    stderr_callbacks = None

    def __init__(self, *args, **kwargs):
        super(InterceptedStreamsMixin, self).__init__(*args, **kwargs)
        self.stdout_callbacks = []
        self.stdout_queue = JoinableQueue()

        self.stderr_callbacks = []
        self.stderr_queue = JoinableQueue()

    def register_stdout_callback(self, callback_fn):
        self.stdout_callbacks.append(callback_fn)

    def register_stderr_callback(self, callback_fn):
        self.stderr_callbacks.append(callback_fn)

    def produce_stdout_queue(self):
        for line in iter(self.proc.stdout.readline, b''):
            self.stdout_queue.put(line)
            time.sleep(0)

    def produce_stderr_queue(self):
        for line in iter(self.proc.stderr.readline, b''):
            self.stderr_queue.put(line)
            time.sleep(0)

    def consume_stdout_queue(self):
        for line in self.stdout_queue:
            for fn in self.stdout_callbacks:
                fn(line.strip())
            self.stdout_queue.task_done()
            time.sleep(0)

    def consume_stderr_queue(self):
        for line in self.stderr_queue:
            for fn in self.stderr_callbacks:
                fn(line.strip())
            self.stderr_queue.task_done()
            time.sleep(0)

    def start(self):
        super(InterceptedStreamsMixin, self).start()

        spawn(self.produce_stdout_queue)
        spawn(self.produce_stderr_queue)

        spawn(self.consume_stdout_queue)
        spawn(self.consume_stderr_queue)

    def stop(self):
        super(InterceptedStreamsMixin, self).stop()

        try:
            self.stdout_queue.put(StopIteration)
            self.stdout_queue.join(5)
        except Timeout:
            pass

        try:
            self.stderr_queue.put(StopIteration)
            self.stderr_queue.join(5)
        except Timeout:
            pass


class LoggingMixin(InterceptedStreamsMixin):
    def __init__(self, *args, **kwargs):
        stdout_logfile_path = kwargs.pop(
            'stdout_logfile_path',
            construct_logger_file_path('geth', 'stdout'),
        )
        stderr_logfile_path = kwargs.pop(
            'stderr_logfile_path',
            construct_logger_file_path('geth', 'stderr'),
        )

        super(LoggingMixin, self).__init__(*args, **kwargs)

        stdout_logger = get_file_logger('geth-stdout', stdout_logfile_path)
        stderr_logger = get_file_logger('geth-stderr', stderr_logfile_path)

        self.register_stdout_callback(stdout_logger.info)
        self.register_stderr_callback(stderr_logger.info)
