#!/usr/bin/env python
# -*- coding: utf-8 -*-
import imp
import os
import sys

from ctypes import (cdll,
                    POINTER, pointer,
                    c_char_p,
                    c_size_t, c_double, c_int, c_uint64, c_uint32,
                    create_string_buffer)

__version__ = '0.8.6'

_scrypt = cdll.LoadLibrary(imp.find_module('_scrypt')[1])

_scryptenc_buf = _scrypt.exp_scryptenc_buf
_scryptenc_buf.argtypes = [c_char_p,  # const uint_t  *inbuf
                           c_size_t,  # size_t         inbuflen
                           c_char_p,  # uint8_t       *outbuf
                           c_char_p,  # const uint8_t *passwd
                           c_size_t,  # size_t         passwdlen
                           c_size_t,  # size_t         maxmem
                           c_double,  # double         maxmemfrac
                           c_double,  # double         maxtime
                           c_int,     # int            verbose
                           ]
_scryptenc_buf.restype = c_int

_scryptdec_buf = _scrypt.exp_scryptdec_buf
_scryptdec_buf.argtypes = [c_char_p,           # const uint8_t *inbuf
                           c_size_t,           # size_t         inbuflen
                           c_char_p,           # uint8_t       *outbuf
                           POINTER(c_size_t),  # size_t        *outlen
                           c_char_p,           # const uint8_t *passwd
                           c_size_t,           # size_t         passwdlen
                           c_size_t,           # size_t         maxmem
                           c_double,           # double         maxmemfrac
                           c_double,           # double         maxtime
                           c_int,              # int            verbose
                           c_int,              # int            force
                           ]
_scryptdec_buf.restype = c_int

_crypto_scrypt = _scrypt.exp_crypto_scrypt
_crypto_scrypt.argtypes = [c_char_p,  # const uint8_t *passwd
                           c_size_t,  # size_t         passwdlen
                           c_char_p,  # const uint8_t *salt
                           c_size_t,  # size_t         saltlen
                           c_uint64,  # uint64_t       N
                           c_uint32,  # uint32_t       r
                           c_uint32,  # uint32_t       p
                           c_char_p,  # uint8_t       *buf
                           c_size_t,  # size_t         buflen
                           ]
_crypto_scrypt.restype = c_int

ERROR_MESSAGES = ['success',
                  'getrlimit or sysctl(hw.usermem) failed',
                  'clock_getres or clock_gettime failed',
                  'error computing derived key',
                  'could not read salt from /dev/urandom',
                  'error in OpenSSL',
                  'malloc failed',
                  'data is not a valid scrypt-encrypted block',
                  'unrecognized scrypt format',
                  'decrypting file would take too much memory',
                  'decrypting file would take too long',
                  'password is incorrect',
                  'error writing output file',
                  'error reading input file']

MAXMEM_DEFAULT = 0
MAXMEMFRAC_DEFAULT = 0.5
MAXTIME_DEFAULT = 300.0
MAXTIME_DEFAULT_ENC = 5.0

IS_PY2 = sys.version_info < (3, 0, 0, 'final', 0)


class error(Exception):
    def __init__(self, scrypt_code):
        if isinstance(scrypt_code, int):
            self._scrypt_code = scrypt_code
            super(error, self).__init__(ERROR_MESSAGES[scrypt_code])
        else:
            self._scrypt_code = -1
            super(error, self).__init__(scrypt_code)


def _ensure_bytes(data):
    if IS_PY2 and isinstance(data, unicode):
        raise TypeError('can not encrypt/decrypt unicode objects')

    if not IS_PY2 and isinstance(data, str):
        return bytes(data, 'utf-8')

    return data


def encrypt(input, password,
            maxtime=MAXTIME_DEFAULT_ENC,
            maxmem=MAXMEM_DEFAULT,
            maxmemfrac=MAXMEMFRAC_DEFAULT):
    """
    Encrypt a string using a password. The resulting data will have len =
    len(input) + 128.

    Notes for Python 2:
      - `input` and `password` must be str instances
      - The result will be a str instance

    Notes for Python 3:
      - `input` and `password` can be both str and bytes. If they are str
        instances, they will be encoded with utf-8
      - The result will be a bytes instance

    Exceptions raised:
      - TypeError on invalid input
      - scrypt.error if encryption failed

    For more information on the `maxtime`, `maxmem`, and `maxmemfrac`
    parameters, see the scrypt documentation.
    """

    input = _ensure_bytes(input)
    password = _ensure_bytes(password)

    outbuf = create_string_buffer(len(input) + 128)
    # verbose is set to zero
    result = _scryptenc_buf(input, len(input),
                            outbuf,
                            password, len(password),
                            maxmem, maxmemfrac, maxtime, 0)
    if result:
        raise error(result)

    return outbuf.raw


def decrypt(input, password,
            maxtime=MAXTIME_DEFAULT,
            maxmem=MAXMEM_DEFAULT,
            maxmemfrac=MAXMEMFRAC_DEFAULT,
            encoding='utf-8'):
    """
    Decrypt a string using a password.

    Notes for Python 2:
      - `input` and `password` must be str instances
      - The result will be a str instance
      - The encoding parameter is ignored

    Notes for Python 3:
      - `input` and `password` can be both str and bytes. If they are str
        instances, they wil be encoded with utf-8. `input` *should*
        really be a bytes instance, since that's what `encrypt` returns.
      - The result will be a str instance encoded with `encoding`.
        If encoding=None, the result will be a bytes instance.

    Exceptions raised:
      - TypeError on invalid input
      - scrypt.error if decryption failed

    For more information on the `maxtime`, `maxmem`, and `maxmemfrac`
    parameters, see the scrypt documentation.
    """

    outbuf = create_string_buffer(len(input))
    outbuflen = pointer(c_size_t(0))

    input = _ensure_bytes(input)
    password = _ensure_bytes(password)
    # verbose and force are set to zero
    result = _scryptdec_buf(input, len(input),
                            outbuf, outbuflen,
                            password, len(password),
                            maxmem, maxmemfrac, maxtime, 0, 0)

    if result:
        raise error(result)

    out_bytes = outbuf.raw[:outbuflen.contents.value]

    if IS_PY2 or encoding is None:
        return out_bytes

    return str(out_bytes, encoding)


def hash(password, salt, N=1 << 14, r=8, p=1, buflen=64):
    """
    Compute scrypt(password, salt, N, r, p, buflen).

    The parameters r, p, and buflen must satisfy r * p < 2^30 and
    buflen <= (2^32 - 1) * 32. The parameter N must be a power of 2
    greater than 1. N, r and p must all be positive.

    Notes for Python 2:
      - `password` and `salt` must be str instances
      - The result will be a str instance

    Notes for Python 3:
      - `password` and `salt` can be both str and bytes. If they are str
        instances, they wil be encoded with utf-8.
      - The result will be a bytes instance

    Exceptions raised:
      - TypeError on invalid input
      - scrypt.error if scrypt failed
    """

    outbuf = create_string_buffer(buflen)

    password = _ensure_bytes(password)
    salt = _ensure_bytes(salt)

    if r * p >= (1 << 30) or N <= 1 or (N & (N - 1)) != 0 or p < 1 or r < 1:
        raise error('hash parameters are wrong (r*p should be < 2**30, and N should be a power of two > 1)')

    result = _crypto_scrypt(password, len(password),
                            salt, len(salt),
                            N, r, p,
                            outbuf, buflen, 0)

    if result:
        raise error('could not compute hash')

    return outbuf.raw


__all__ = ['error', 'encrypt', 'decrypt', 'hash']
