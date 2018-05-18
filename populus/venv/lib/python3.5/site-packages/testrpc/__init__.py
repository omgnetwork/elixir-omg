import pkg_resources


try:
    from sha3 import keccak_256  # NOQA
except ImportError:
    pass
else:
    import sha3
    sha3.sha3_256 = sha3.keccak_256


__version__ = pkg_resources.get_distribution("eth-testrpc").version
