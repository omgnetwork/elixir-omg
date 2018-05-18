from __future__ import absolute_import

import codecs
import collections
import sys
from typing import (Any, Optional, Text, Tuple)  # noqa: F401

from eth_utils import (
    big_endian_to_int,
    int_to_big_endian,
    is_bytes,
    keccak,
    to_checksum_address,
    to_normalized_address,
)

from eth_keys.utils.address import (
    public_key_bytes_to_address,
)
from eth_keys.utils.numeric import (
    int_to_byte,
)
from eth_keys.utils.padding import (
    pad32,
)

from eth_keys.exceptions import (
    BadSignature,
    ValidationError,
)
from eth_keys.validation import (
    validate_gte,
    validate_integer,
    validate_lt_secpk1n,
    validate_lte,
    validate_private_key_bytes,
    validate_public_key_bytes,
    validate_signature_bytes,
)


# Workaround for import cycles caused by type annotations:
# http://mypy.readthedocs.io/en/latest/common_issues.html#import-cycles
MYPY = False
if MYPY:
    from eth_keys.backends.base import BaseECCBackend  # noqa: F401


# Must compare against version_info[0] and not version_info.major to please mypy.
if sys.version_info[0] == 2:
    ByteString = type(
        b'BaseString',
        (collections.Sequence, basestring),  # noqa: F821
        {},
    )  # type: Any
else:
    ByteString = collections.abc.ByteString


class BackendProxied(object):
    _backend = None

    @property
    def backend(self):
        # type: () -> BaseECCBackend
        from eth_keys.backends import get_backend

        if self._backend is None:
            return get_backend()
        else:
            return self._backend

    @classmethod
    def get_backend(cls):
        # type: () -> BaseECCBackend
        from eth_keys.backends import get_backend

        if cls._backend is None:
            return get_backend()
        else:
            return cls._backend


class BaseKey(ByteString, collections.Hashable):
    _raw_key = None  # type: bytes

    def to_hex(self):
        # type: () -> Text
        # Need the 'type: ignore' comment below because of
        # https://github.com/python/typeshed/issues/300
        return '0x' + codecs.decode(codecs.encode(self._raw_key, 'hex'), 'ascii')  # type: ignore

    def to_bytes(self):
        # type: () -> bytes
        return self._raw_key

    def __hash__(self):
        return big_endian_to_int(keccak(self.to_bytes()))

    def __str__(self):
        return self.to_hex()

    def __unicode__(self):
        return self.__str__()

    def __int__(self):
        return big_endian_to_int(self._raw_key)

    def __len__(self):
        return 64

    def __getitem__(self, index):
        return self._raw_key[index]

    def __eq__(self,
               other  # type: Any
               ):
        # type: (...) -> bool
        if hasattr(other, 'to_bytes'):
            return self.to_bytes() == other.to_bytes()
        elif is_bytes(other):
            return self.to_bytes() == other
        else:
            return False

    def __repr__(self):
        return "'{0}'".format(self.to_hex())

    def __index__(self):
        return self.__int__()

    def __hex__(self):
        # type: () -> Text
        if sys.version_info[0] == 2:
            return codecs.encode(self.to_hex(), 'ascii')
        else:
            return self.to_hex()


class PublicKey(BaseKey, BackendProxied):
    def __init__(self, public_key_bytes):
        # type: (bytes) -> None
        validate_public_key_bytes(public_key_bytes)

        self._raw_key = public_key_bytes

    @classmethod
    def from_private(cls, private_key):
        # type: (PrivateKey) -> PublicKey
        return cls.get_backend().private_key_to_public_key(private_key)

    @classmethod
    def recover_from_msg(cls, message, signature):
        # type: (bytes, Signature) -> PublicKey
        message_hash = keccak(message)
        return cls.recover_from_msg_hash(message_hash, signature)

    @classmethod
    def recover_from_msg_hash(cls, message_hash, signature):
        # type: (bytes, Signature) -> PublicKey
        return cls.get_backend().ecdsa_recover(message_hash, signature)

    def verify_msg(self, message, signature):
        # type: (bytes, Signature) -> bool
        message_hash = keccak(message)
        return self.verify_msg_hash(message_hash, signature)

    def verify_msg_hash(self, message_hash, signature):
        # type: (bytes, Signature) -> bool
        return self.backend.ecdsa_verify(message_hash, signature, self)

    #
    # Ethereum address conversions
    #
    def to_checksum_address(self):
        # type: () -> bytes
        return to_checksum_address(public_key_bytes_to_address(self.to_bytes()))

    def to_address(self):
        # type: () -> bytes
        return to_normalized_address(public_key_bytes_to_address(self.to_bytes()))

    def to_canonical_address(self):
        # type: () -> bytes
        return public_key_bytes_to_address(self.to_bytes())


class PrivateKey(BaseKey, BackendProxied):
    public_key = None  # type: PublicKey

    def __init__(self, private_key_bytes):
        # type: (bytes) -> None
        validate_private_key_bytes(private_key_bytes)

        self._raw_key = private_key_bytes

        self.public_key = self.backend.private_key_to_public_key(self)

    def sign_msg(self, message):
        # type: (bytes) -> Signature
        message_hash = keccak(message)
        return self.sign_msg_hash(message_hash)

    def sign_msg_hash(self, message_hash):
        # type: (bytes) -> Signature
        return self.backend.ecdsa_sign(message_hash, self)


class Signature(ByteString, BackendProxied):
    _backend = None
    _v = None  # type: int
    _r = None  # type: int
    _s = None  # type: int

    def __init__(self, signature_bytes=None, vrs=None):
        # type: (Optional[bytes], Optional[Tuple[int, int, int]]) -> None
        if bool(signature_bytes) is bool(vrs):
            raise TypeError("You must provide one of `signature_bytes` or `vrs`")
        elif signature_bytes:
            validate_signature_bytes(signature_bytes)
            try:
                self.r = big_endian_to_int(signature_bytes[0:32])
                self.s = big_endian_to_int(signature_bytes[32:64])
                self.v = ord(signature_bytes[64:65])
            except ValidationError as err:
                raise BadSignature(str(err))
        elif vrs:
            v, r, s, = vrs
            try:
                self.v = v
                self.r = r
                self.s = s
            except ValidationError as err:
                raise BadSignature(str(err))
        else:
            raise TypeError("Invariant: unreachable code path")

    #
    # v
    #
    @property
    def v(self):
        # type: () -> int
        return self._v

    @v.setter
    def v(self, value):
        # type: (int) -> None
        validate_integer(value)
        validate_gte(value, minimum=0)
        validate_lte(value, maximum=1)

        self._v = value

    #
    # r
    #
    @property
    def r(self):
        # type: () -> int
        return self._r

    @r.setter
    def r(self, value):
        # type: (int) -> None
        validate_integer(value)
        validate_gte(value, 0)
        validate_lt_secpk1n(value)

        self._r = value

    #
    # s
    #
    @property
    def s(self):
        # type: () -> int
        return self._s

    @s.setter
    def s(self, value):
        # type: (int) -> None
        validate_integer(value)
        validate_gte(value, 0)
        validate_lt_secpk1n(value)

        self._s = value

    @property
    def vrs(self):
        # type: () -> Tuple[int, int, int]
        return (self.v, self.r, self.s)

    def to_hex(self):
        # type: () -> Text
        # Need the 'type: ignore' comment below because of
        # https://github.com/python/typeshed/issues/300
        return '0x' + codecs.decode(codecs.encode(self.to_bytes(), 'hex'), 'ascii')  # type: ignore

    def to_bytes(self):
        # type: () -> bytes
        return self.__bytes__()

    def __hash__(self):
        return big_endian_to_int(keccak(self.to_bytes()))

    def __bytes__(self):
        # type: () -> bytes
        vb = int_to_byte(self.v)
        rb = pad32(int_to_big_endian(self.r))
        sb = pad32(int_to_big_endian(self.s))
        # FIXME: Enable type checking once we have type annotations in eth_utils
        return b''.join((rb, sb, vb))  # type: ignore

    def __str__(self):
        return self.to_hex()

    def __unicode__(self):
        return self.__str__()

    def __len__(self):
        return 65

    def __eq__(self, other):
        if hasattr(other, 'to_bytes'):
            return self.to_bytes() == other.to_bytes()
        elif is_bytes(other):
            return self.to_bytes() == other
        else:
            return False

    def __getitem__(self, index):
        return self.to_bytes()[index]

    def __repr__(self):
        return "'{0}'".format(self.to_hex())

    def verify_msg(self, message, public_key):
        # type: (bytes, PublicKey) -> bool
        message_hash = keccak(message)
        return self.verify_msg_hash(message_hash, public_key)

    def verify_msg_hash(self, message_hash, public_key):
        # type: (bytes, PublicKey) -> bool
        return self.backend.ecdsa_verify(message_hash, self, public_key)

    def recover_public_key_from_msg(self, message):
        # type: (bytes) -> PublicKey
        message_hash = keccak(message)
        return self.recover_public_key_from_msg_hash(message_hash)

    def recover_public_key_from_msg_hash(self, message_hash):
        # type: (bytes) -> PublicKey
        return self.backend.ecdsa_recover(message_hash, self)

    def __index__(self):
        return self.__int__()

    def __hex__(self):
        # type: () -> Text
        if sys.version_info[0] == 2:
            return codecs.encode(self.to_hex(), 'ascii')
        else:
            return self.to_hex()

    def __int__(self):
        return big_endian_to_int(self.to_bytes())
