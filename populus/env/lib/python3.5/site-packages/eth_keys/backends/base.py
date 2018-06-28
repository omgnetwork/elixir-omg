from typing import Any  # noqa: F401

from eth_keys import datatypes


class BaseECCBackend(object):
    def __init__(self):
        # type: () -> None
        # Mypy cannot detect the type of dynamically computed classes
        # (https://github.com/python/mypy/issues/2477), so we must annotate those with Any
        self.PublicKey = type(
            '{0}PublicKey'.format(type(self).__name__),
            (datatypes.PublicKey,),
            {'_backend': self},
        )  # type: Any
        self.PrivateKey = type(
            '{0}PrivateKey'.format(type(self).__name__),
            (datatypes.PrivateKey,),
            {'_backend': self},
        )  # type: Any
        self.Signature = type(
            '{0}Signature'.format(type(self).__name__),
            (datatypes.Signature,),
            {'_backend': self},
        )  # type: Any

    def ecdsa_sign(self,
                   msg_hash,    # type: bytes
                   private_key  # type: datatypes.PrivateKey
                   ):
        # type: (...) -> datatypes.Signature
        raise NotImplementedError()

    def ecdsa_verify(self,
                     msg_hash,   # type: bytes
                     signature,  # type: datatypes.Signature
                     public_key  # type: datatypes.PublicKey
                     ):
        # type: (...) -> bool
        return self.ecdsa_recover(msg_hash, signature) == public_key

    def ecdsa_recover(self,
                      msg_hash,  # type: bytes
                      signature  # type: datatypes.Signature
                      ):
        # type: (...) -> datatypes.PublicKey
        raise NotImplementedError()

    def private_key_to_public_key(self,
                                  private_key  # type: datatypes.PrivateKey
                                  ):
        # type: (...) -> datatypes.PublicKey
        raise NotImplementedError()
