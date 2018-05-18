import sys
import functools
import random
import codecs

from rlp.utils import (
    int_to_big_endian,
    big_endian_to_int,
    encode_hex,
    decode_hex as _decode_hex,
)
from ethereum.utils import (
    is_numeric,
    normalize_address as _normalize_address,
    zpad,
)


if sys.version_info.major == 2:
    integer_types = (int, long)  # NOQA
    binary_types = (bytes, bytearray)
    text_types = (unicode,)  # NOQA
    string_types = (basestring, bytearray)  # NOQA
else:
    integer_types = (int,)  # NOQA
    binary_types = (bytes, bytearray)
    text_types = (str,)
    string_types = (bytes, str, bytearray)


def is_binary(value):
    return isinstance(value, binary_types)


def is_text(value):
    return isinstance(value, text_types)


def is_string(value):
    return isinstance(value, string_types)


def is_integer(value):
    return isinstance(value, integer_types)


def is_array(value):
    return isinstance(value, (list, tuple))


def force_bytes(value):
    if is_binary(value):
        return bytes(value)
    elif is_text(value):
        return codecs.encode(value, "iso-8859-1")
    else:
        raise TypeError("Unsupported type: {0}".format(type(value)))


def force_text(value):
    if is_text(value):
        return value
    elif is_binary(value):
        return codecs.decode(value, "iso-8859-1")
    else:
        raise TypeError("Unsupported type: {0}".format(type(value)))


def force_obj_to_bytes(obj, skip_unsupported=False):
    if is_string(obj):
        return force_bytes(obj)
    elif isinstance(obj, dict):
        return {
            k: force_obj_to_bytes(v, skip_unsupported) for k, v in obj.items()
        }
    elif isinstance(obj, (list, tuple)):
        return type(obj)(force_obj_to_bytes(v, skip_unsupported) for v in obj)
    elif not skip_unsupported:
        raise ValueError("Unsupported type: {0}".format(type(obj)))
    else:
        return obj


def force_obj_to_text(obj, skip_unsupported=False):
    if is_string(obj):
        return force_text(obj)
    elif isinstance(obj, dict):
        return {
            k: force_obj_to_text(v, skip_unsupported) for k, v in obj.items()
        }
    elif isinstance(obj, (list, tuple)):
        return type(obj)(force_obj_to_text(v, skip_unsupported) for v in obj)
    elif not skip_unsupported:
        raise ValueError("Unsupported type: {0}".format(type(obj)))
    else:
        return obj


def coerce_args_to_bytes(fn):
    @functools.wraps(fn)
    def inner(*args, **kwargs):
        bytes_args = force_obj_to_bytes(args, True)
        bytes_kwargs = force_obj_to_bytes(kwargs, True)
        return fn(*bytes_args, **bytes_kwargs)
    return inner


def coerce_return_to_bytes(fn):
    @functools.wraps(fn)
    def inner(*args, **kwargs):
        return force_obj_to_bytes(fn(*args, **kwargs), True)
    return inner


@coerce_args_to_bytes
def strip_0x(value):
    if value.startswith(b'0x'):
        return value[2:]
    return value


@coerce_args_to_bytes
def add_0x(value):
    return b"0x" + strip_0x(value)


@coerce_args_to_bytes
def normalize_address(value, allow_blank=True):
    return _normalize_address(value, allow_blank)


@coerce_args_to_bytes
def normalize_number(value):
    if is_numeric(value):
        return value
    elif is_string(value):
        if value.startswith(b'0x'):
            return int(value, 16)
        else:
            return big_endian_to_int(value)
    else:
        raise ValueError("Unknown numeric encoding: {0}".format(value))


@coerce_return_to_bytes
def encode_address(address):
    return add_0x(encode_hex(normalize_address(address, allow_blank=True)))


@coerce_return_to_bytes
def encode_data(data, length=None):
    """Encode unformatted binary `data`.

    If `length` is given, the result will be padded like this: ``quantity_encoder(255, 3) ==
    '0x0000ff'``.
    """
    return add_0x(encode_hex(zpad(data, length or 0)))


@coerce_return_to_bytes
def encode_32bytes(value):
    return encode_data(value, 32)


@coerce_return_to_bytes
def encode_number(value, length=None):
    """Encode interger quantity `data`."""
    if not is_numeric(value):
        raise ValueError("Unsupported type: {0}".format(type(value)))
    hex_value = encode_data(int_to_big_endian(value), length)

    if length:
        return hex_value
    else:
        return add_0x(strip_0x(hex_value).lstrip(b'0') or b'0')


@coerce_args_to_bytes
def decode_hex(value):
    return _decode_hex(strip_0x(value))


def mk_random_privkey():
    return decode_hex(encode_number(random.getrandbits(256), 32))


def normalize_block_identifier(block_identifier):
    if block_identifier is None:
        return None
    elif block_identifier in ["latest", "earliest", "pending"]:
        return block_identifier
    else:
        return normalize_number(block_identifier)
