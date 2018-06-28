import textwrap

from .utils.string import force_text


def force_text_maybe(value, encoding='iso-8859-1'):
    if value is not None:
        return force_text(value)


DEFAULT_MESSAGE = "An error occurred during execution"


class SolcError(Exception):
    message = DEFAULT_MESSAGE

    def __init__(self, command, return_code, stdin_data, stdout_data, stderr_data, message=None):
        if message is not None:
            self.message = message
        self.command = command
        self.return_code = return_code
        self.stdin_data = force_text_maybe(stdin_data, 'utf8')
        self.stderr_data = force_text_maybe(stderr_data, 'utf8')
        self.stdout_data = force_text_maybe(stdout_data, 'utf8')

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


class ContractsNotFound(SolcError):
    message = "No contracts found during compilation"
