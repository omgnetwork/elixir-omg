import re

import semantic_version

from .utils.encoding import (
    force_text,
)
from .wrapper import (  # noqa: E402
    geth_wrapper,
)


def get_geth_version_info_string(**geth_kwargs):
    if 'suffix_args' in geth_kwargs:
        raise TypeError(
            "The `get_geth_version` function cannot be called with the "
            "`suffix_args` parameter"
        )
    geth_kwargs['suffix_args'] = ['version']
    stdoutdata, stderrdata, command, proc = geth_wrapper(**geth_kwargs)
    return stdoutdata


VERSION_REGEX = r'Version: (.*)\n'


def get_geth_version(**geth_kwargs):
    version_info_string = get_geth_version_info_string(**geth_kwargs)
    version_match = re.search(VERSION_REGEX, force_text(version_info_string, 'utf8'))
    if not version_match:
        raise ValueError(
            "Did not match version string in geth output:\n{0}".format(version_info_string)
        )
    version_string = version_match.groups()[0]
    return semantic_version.Version(version_string)
