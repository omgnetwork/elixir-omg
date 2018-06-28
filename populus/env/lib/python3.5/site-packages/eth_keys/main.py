from typing import (Any, Optional, Union)  # noqa: F401

from eth_utils import (
    is_string,
)

from eth_keys.backends import (
    BaseECCBackend,
    get_backend,
)
from eth_keys.datatypes import (
    PublicKey,
    PrivateKey,
    Signature,
)
from eth_keys.exceptions import (
    ValidationError,
)
from eth_keys.validation import (
    validate_message_hash,
)


def backend_property_proxy(name):
    @property
    def property_fn(self):
        backend_property = getattr(self.backend, name)
        return backend_property
    return property_fn


class KeyAPI(object):
    backend = None

    def __init__(self, backend=None):
        if backend is None:
            pass
        elif isinstance(backend, BaseECCBackend):
            pass
        elif isinstance(backend, type) and issubclass(backend, BaseECCBackend):
            backend = backend()
        elif is_string(backend):
            backend = get_backend(backend)
        else:
            raise ValueError(
                "Unsupported format for ECC backend.  Must be an instance or "
                "subclass of `eth_keys.backends.BaseECCBackend` or a string of "
                "the dot-separated import path for the desired backend class"
            )

        self.backend = backend

    _backend = None

    @property
    def backend(self):
        if self._backend is None:
            return get_backend()
        else:
            return self._backend

    @backend.setter
    def backend(self, value):
        self._backend = value

    #
    # Proxy method calls to the backends
    #
    # Mypy cannot detect the type of dynamically computed classes
    # (https://github.com/python/mypy/issues/2477), so we must annotate those with Any
    PublicKey = backend_property_proxy('PublicKey')  # type: Any
    PrivateKey = backend_property_proxy('PrivateKey')  # type: Any
    Signature = backend_property_proxy('Signature')  # type: Any

    def ecdsa_sign(self,
                   message_hash,  # type: bytes
                   private_key  # type: Union[PrivateKey, bytes]
                   ):
        # type: (...) -> Optional[Signature]
        validate_message_hash(message_hash)
        if not isinstance(private_key, PrivateKey):
            raise ValidationError(
                "The `private_key` must be an instance of `eth_keys.datatypes.PrivateKey`"
            )
        signature = self.backend.ecdsa_sign(message_hash, private_key)
        if not isinstance(signature, Signature):
            raise ValidationError(
                "Backend returned an invalid signature.  Return value must be "
                "an instance of `eth_keys.datatypes.Signature`"
            )
        return signature

    def ecdsa_verify(self,
                     message_hash,  # type: bytes
                     signature,  # type: Union[Signature, bytes]
                     public_key  # type: Union[PublicKey, bytes]
                     ):
        # type: (...) -> Optional[bool]
        if not isinstance(public_key, PublicKey):
            raise ValidationError(
                "The `public_key` must be an instance of `eth_keys.datatypes.PublicKey`"
            )
        return self.ecdsa_recover(message_hash, signature) == public_key

    def ecdsa_recover(self,
                      message_hash,  # type: bytes
                      signature  # type: Union[Signature, bytes]
                      ):
        # type: (...) -> Optional[PublicKey]
        validate_message_hash(message_hash)
        if not isinstance(signature, Signature):
            raise ValidationError(
                "The `signature` must be an instance of `eth_keys.datatypes.Signature`"
            )
        public_key = self.backend.ecdsa_recover(message_hash, signature)
        if not isinstance(public_key, PublicKey):
            raise ValidationError(
                "Backend returned an invalid public_key.  Return value must be "
                "an instance of `eth_keys.datatypes.PublicKey`"
            )
        return public_key

    def private_key_to_public_key(self, private_key):
        if not isinstance(private_key, PrivateKey):
            raise ValidationError(
                "The `private_key` must be an instance of `eth_keys.datatypes.PrivateKey`"
            )
        public_key = self.backend.private_key_to_public_key(private_key)
        if not isinstance(public_key, PublicKey):
            raise ValidationError(
                "Backend returned an invalid public_key.  Return value must be "
                "an instance of `eth_keys.datatypes.PublicKey`"
            )
        return public_key


# This creates an easy to import backend which will lazily fetch whatever
# backend has been configured at runtime (as opposed to import or instantiation time).
lazy_key_api = KeyAPI(backend=None)
