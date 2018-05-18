from cytoolz import (
    partial,
)

from eth_utils import (
    pad_left,
)


pad32 = partial(pad_left, to_size=32, pad_with=b'\x00')
