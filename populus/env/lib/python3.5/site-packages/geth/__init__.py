import pkg_resources
import sys
import warnings

from .main import (  # noqa: F401
    get_geth_version,
)
from .install import (  # noqa: F401
    install_geth,
)
from .process import (  # noqa: F401
    LiveGethProcess,
    MainnetGethProcess,
    RopstenGethProcess,
    TestnetGethProcess,
    DevGethProcess,
)
from .mixins import (  # noqa: F401
    InterceptedStreamsMixin,
    LoggingMixin,
)


if sys.version_info.major < 3:
    warnings.simplefilter('always', DeprecationWarning)
    warnings.warn(DeprecationWarning(
        "The `py-geth` library is dropping support for Python 2.  Upgrade to Python 3."
    ))
    warnings.resetwarnings()


__version__ = pkg_resources.get_distribution("py-geth").version
