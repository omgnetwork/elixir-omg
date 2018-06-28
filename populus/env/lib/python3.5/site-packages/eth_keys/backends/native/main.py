from __future__ import absolute_import

from typing import Optional  # noqa: F401

from .ecdsa import (
    ecdsa_raw_recover,
    ecdsa_raw_sign,
    private_key_to_public_key,
)

from eth_keys.backends.base import BaseECCBackend
from eth_keys.datatypes import (  # noqa: F401
    PrivateKey,
    PublicKey,
    Signature,
)


class NativeECCBackend(BaseECCBackend):
    def ecdsa_sign(self, msg_hash, private_key):
        # type: (bytes, PrivateKey) -> Signature
        signature_vrs = ecdsa_raw_sign(msg_hash, private_key.to_bytes())
        signature = self.Signature(vrs=signature_vrs)
        return signature

    def ecdsa_recover(self,
                      msg_hash,  # type: bytes
                      signature  # type: Signature
                      ):
        # type: (...) -> Optional[PublicKey]
        public_key_bytes = ecdsa_raw_recover(msg_hash, signature.vrs)
        public_key = self.PublicKey(public_key_bytes)
        return public_key

    def private_key_to_public_key(self, private_key):
        # type: (PrivateKey) -> PublicKey
        public_key_bytes = private_key_to_public_key(private_key.to_bytes())
        public_key = self.PublicKey(public_key_bytes)
        return public_key
