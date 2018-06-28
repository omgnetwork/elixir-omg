import sys


if sys.version_info.major == 2:
    int_to_byte = chr
else:
    def int_to_byte(value):
        return bytes([value])
