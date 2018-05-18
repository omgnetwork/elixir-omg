"""
Functions lifted from https://github.com/vbuterin/pybitcointools
"""
import hashlib
import hmac
from typing import (Any, Callable, Optional, Tuple)  # noqa: F401

from eth_utils import (
    int_to_big_endian,
    big_endian_to_int,
)

from eth_keys.constants import (
    SECPK1_N as N,
    SECPK1_G as G,
    SECPK1_Gx as Gx,
    SECPK1_Gy as Gy,
    SECPK1_P as P,
    SECPK1_A as A,
    SECPK1_B as B,
)
from eth_keys.exceptions import (
    BadSignature,
)

from eth_keys.utils.padding import pad32

from .jacobian import (
    inv,
    fast_multiply,
    fast_add,
    jacobian_add,
    jacobian_multiply,
    from_jacobian,
)


def decode_public_key(public_key_bytes):
    left = big_endian_to_int(public_key_bytes[0:32])
    right = big_endian_to_int(public_key_bytes[32:64])
    return left, right


def encode_raw_public_key(raw_public_key):
    # type: (Tuple[int, int]) -> bytes
    left, right = raw_public_key
    return b''.join((
        pad32(int_to_big_endian(left)),
        pad32(int_to_big_endian(right)),
    ))


def private_key_to_public_key(private_key_bytes):
    # type: (bytes) -> bytes
    private_key_as_num = big_endian_to_int(private_key_bytes)

    if private_key_as_num >= N:
        raise Exception("Invalid privkey")

    raw_public_key = fast_multiply(G, private_key_as_num)
    public_key_bytes = encode_raw_public_key(raw_public_key)
    return public_key_bytes


def deterministic_generate_k(msg_hash, private_key_bytes, digest_fn=hashlib.sha256):
    # type: (bytes, bytes, Callable[[], Any]) -> int
    v_0 = b'\x01' * 32
    k_0 = b'\x00' * 32

    k_1 = hmac.new(k_0, v_0 + b'\x00' + private_key_bytes + msg_hash, digest_fn).digest()
    v_1 = hmac.new(k_1, v_0, digest_fn).digest()
    k_2 = hmac.new(k_1, v_1 + b'\x01' + private_key_bytes + msg_hash, digest_fn).digest()
    v_2 = hmac.new(k_2, v_1, digest_fn).digest()

    kb = hmac.new(k_2, v_2, digest_fn).digest()
    k = big_endian_to_int(kb)
    return k


def ecdsa_raw_sign(msg_hash, private_key_bytes):
    # type: (bytes, bytes) -> Tuple[int, int, int]
    z = big_endian_to_int(msg_hash)
    k = deterministic_generate_k(msg_hash, private_key_bytes)

    r, y = fast_multiply(G, k)
    s_raw = inv(k, N) * (z + r * big_endian_to_int(private_key_bytes)) % N

    v = 27 + ((y % 2) ^ (0 if s_raw * 2 < N else 1))
    s = s_raw if s_raw * 2 < N else N - s_raw

    return v - 27, r, s


def ecdsa_raw_verify(msg_hash, vrs, public_key_bytes):
    # type: (bytes, Tuple[int, int, int], bytes) -> Optional[bool]
    raw_public_key = decode_public_key(public_key_bytes)

    v, r, s = vrs
    v += 27
    if not (27 <= v <= 34):
        raise BadSignature("Invalid Signature")

    w = inv(s, N)
    z = big_endian_to_int(msg_hash)

    u1, u2 = z * w % N, r * w % N
    x, y = fast_add(
        fast_multiply(G, u1),
        fast_multiply(raw_public_key, u2),
    )
    return bool(r == x and (r % N) and (s % N))


def ecdsa_raw_recover(msg_hash, vrs):
    # type: (bytes, Tuple[int, int, int]) -> Optional[bytes]
    v, r, s = vrs
    v += 27

    if not (27 <= v <= 34):
        raise BadSignature("%d must in range 27-31" % v)

    x = r

    xcubedaxb = (x * x * x + A * x + B) % P
    beta = pow(xcubedaxb, (P + 1) // 4, P)
    y = beta if v % 2 ^ beta % 2 else (P - beta)
    # If xcubedaxb is not a quadratic residue, then r cannot be the x coord
    # for a point on the curve, and so the sig is invalid
    if (xcubedaxb - y * y) % P != 0 or not (r % N) or not (s % N):
        raise BadSignature("Invalid signature")
    z = big_endian_to_int(msg_hash)
    Gz = jacobian_multiply((Gx, Gy, 1), (N - z) % N)
    XY = jacobian_multiply((x, y, 1), s)
    Qr = jacobian_add(Gz, XY)
    Q = jacobian_multiply(Qr, inv(r, N))
    raw_public_key = from_jacobian(Q)

    return encode_raw_public_key(raw_public_key)
