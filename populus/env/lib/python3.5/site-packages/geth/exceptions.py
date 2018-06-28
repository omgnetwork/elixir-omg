import textwrap

from .utils.encoding import force_text


def force_text_maybe(value):
    if value is not None:
        return force_text(value, 'utf8')


DEFAULT_MESSAGE = "An error occurred during execution"


class GethError(Exception):
    message = DEFAULT_MESSAGE

    def __init__(self, command, return_code, stdin_data, stdout_data, stderr_data, message=None):
        if message is not None:
            self.message = message
        self.command = command
        self.return_code = return_code
        self.stdin_data = force_text_maybe(stdin_data)
        self.stderr_data = force_text_maybe(stderr_data)
        self.stdout_data = force_text_maybe(stdout_data)

    def __str__(self):
        return textwrap.dedent(("""
        {s.message}
        > command: `{command}`
        > return code: `{s.return_code}`
        > stderr:
        {s.stdout_data}
        > stdout:
        {s.stderr_data}
        """).format(
            s=self,
            command=' '.join(self.command),
        )).strip()
