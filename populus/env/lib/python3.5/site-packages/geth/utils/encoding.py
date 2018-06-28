import codecs
import sys


if sys.version_info.major == 2:
    binary_types = (bytes, bytearray)
    text_types = (unicode,)  # NOQA
    string_types = (basestring, bytearray)  # NOQA
else:
    binary_types = (bytes, bytearray)
    text_types = (str,)
    string_types = (bytes, str, bytearray)


def is_binary(value):
    return isinstance(value, binary_types)


def is_text(value):
    return isinstance(value, text_types)


def is_string(value):
    return isinstance(value, string_types)


def force_bytes(value, encoding='iso-8859-1'):
    if is_binary(value):
        return bytes(value)
    elif is_text(value):
        return codecs.encode(value, encoding)
    else:
        raise TypeError("Unsupported type: {0}".format(type(value)))


def force_text(value, encoding='iso-8859-1'):
    if is_text(value):
        return value
    elif is_binary(value):
        return codecs.decode(value, encoding)
    else:
        raise TypeError("Unsupported type: {0}".format(type(value)))


def force_obj_to_text(obj):
    if is_string(obj):
        return force_text(obj)
    elif isinstance(obj, dict):
        return {
            force_obj_to_text(k): force_obj_to_text(v) for k, v in obj.items()
        }
    elif isinstance(obj, (list, tuple)):
        return type(obj)(force_obj_to_text(v) for v in obj)
    else:
        return obj
