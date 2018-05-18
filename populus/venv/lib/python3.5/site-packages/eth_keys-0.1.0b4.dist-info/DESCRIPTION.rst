Ethereum Keys
=============

A common API for Ethereum key operations with pluggable backends.

    This library and repository was previously located at
    https://github.com/pipermerriam/ethereum-keys. It was transferred to
    the Ethereum foundation github in November 2017 and renamed to
    ``eth-keys``. The PyPi package was also renamed from
    ``ethereum-keys`` to \`eth-keys.

Installation
------------

.. code:: sh

    pip install eth-keys

Development
-----------

.. code:: sh

    pip install -e . -r requirements-dev.txt

Running the tests
~~~~~~~~~~~~~~~~~

You can run the tests with:

.. code:: sh

    py.test tests

Or you can install ``tox`` to run the full test suite.

Releasing
~~~~~~~~~

Pandoc is required for transforming the markdown README to the proper
format to render correctly on pypi.

For Debian-like systems:

::

    apt install pandoc

Or on OSX:

.. code:: sh

    brew install pandoc

To release a new version:

.. code:: sh

    bumpversion $$VERSION_PART_TO_BUMP$$
    git push && git push --tags
    make release

How to bumpversion
^^^^^^^^^^^^^^^^^^

The version format for this repo is ``{major}.{minor}.{patch}`` for
stable, and ``{major}.{minor}.{patch}-{stage}.{devnum}`` for unstable
(``stage`` can be alpha or beta).

To issue the next version in line, use bumpversion and specify which
part to bump, like ``bumpversion minor`` or ``bumpversion devnum``.

If you are in a beta version, ``bumpversion stage`` will switch to a
stable.

To issue an unstable version when the current version is stable, specify
the new version explicitly, like
``bumpversion --new-version 4.0.0-alpha.1 devnum``

QuickStart
----------

.. code:: python

    >>> from eth_keys import keys
    >>> pk = keys.PrivateKey(b'\x01' * 32)
    >>> signature = pk.sign_msg(b'a message')
    >>> pk
    '0x0101010101010101010101010101010101010101010101010101010101010101'
    >>> pk.public_key
    '0x1b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f70beaf8f588b541507fed6a642c5ab42dfdf8120a7f639de5122d47a69a8e8d1'
    >>> signature
    '0xccda990dba7864b79dc49158fea269338a1cf5747bc4c4bf1b96823e31a0997e7d1e65c06c5bf128b7109e1b4b9ba8d1305dc33f32f624695b2fa8e02c12c1e000'
    >>> pk.public_key.to_checksum_address()
    '0x1a642f0E3c3aF545E7AcBD38b07251B3990914F1'
    >>> signature.verify_msg(b'a message', pk.public_key)
    True
    >>> signature.recover_msg(b'a message') == pk.public_key
    True

Documentation
-------------

``KeyAPI(backend=None)``
~~~~~~~~~~~~~~~~~~~~~~~~

The ``KeyAPI`` object is the primary API for interacting with the
``eth-keys`` libary. The object takes a single optional argument in it’s
constructor which designates what backend will be used for eliptical
curve cryptography operations. The built-in backends are:

-  ``eth_keys.backends.NativeECCBackend`` A pure python implementation
   of the ECC operations.
-  ``eth_keys.backends.CoinCurveECCBackend``: Uses the
   ```coincurve`` <https://github.com/ofek/coincurve>`__ library for ECC
   operations.

By default, ``eth-keys`` will *try* to use the ``CoinCurveECCBackend``,
falling back to the ``NativeECCBackend`` if the ``coincurve`` library is
not available.

    Note: The ``coincurve`` library is not automatically installed with
    ``eth-keys`` and must be installed separately.

The ``backend`` argument can be given in any of the following forms.

-  Instance of the backend class
-  The backend class
-  String with the dot-separated import path for the backend class.

.. code:: python

    >>> from eth_keys import KeyAPI
    >>> from eth_keys.backends import NativeECCBackend
    # These are all the same
    >>> keys = KeyAPI(NativeECCBackend)
    >>> keys = KeyAPI(NativeECCBackend())
    >>> keys = KeyAPI('eth_keys.backends.NativeECCBackend')
    # Or for the coincurve base backend
    >>> keys = KeyAPI('eth_keys.backends.CoinCurveECCBackend')

The backend can also be configured using the environment variable
``ECC_BACKEND_CLASS`` which should be set to the dot-separated python
import path to the desired backend.

.. code:: python

    >>> import os
    >>> os.environ['ECC_BACKEND_CLASS'] = 'eth_keys.backends.CoinCurveECCBackend'

``KeyAPI.ecdsa_sign(message_hash, private_key) -> Signature``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This method returns a signature for the given ``message_hash``, signed
by the provided ``public_key``.

-  ``message_hash``: **must** be a byte string of length 32
-  ``private_key``: **must** be an instance of ``PrivateKey``

``KeyAPI.ecdsa_verify(message_hash, signature, public_key) -> bool``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns ``True`` or ``False`` based on whether the provided
``signature`` is a valid signature for the provided ``message_hash`` and
``public_key``.

-  ``message_hash``: **must** be a byte string of length 32
-  ``signature``: **must** be an instance of ``Signature``
-  ``public_key``: **must** be an instance of ``PublicKey``

``KeyAPI.ecdsa_recover(message_hash, signature) -> PublicKey``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the ``PublicKey`` instances recovered from the given
``signature`` and ``message_hash``.

-  ``message_hash``: **must** be a byte string of length 32
-  ``signature``: **must** be an instance of ``Signature``

``KeyAPI.private_key_to_public_key(private_key) -> PublicKey``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the ``PublicKey`` instances computed from the given
``private_key`` instance.

-  ``private_key``: **must** be an instance of ``PublicKey``

Common APIs for ``PublicKey``, ``PrivateKey`` and ``Signature``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There is a common API for the following objects.

-  ``PublicKey``
-  ``PrivateKey``
-  ``Signature``

Each of these objects has all of the following APIs.

-  ``obj.to_bytes()``: Returns the object in it’s canonical ``bytes``
   serialization.
-  ``obj.to_hex()``: Returns a text string of the hex encoded canonical
   representation.

``KeyAPI.PublicKey(public_key_bytes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``PublicKey`` class takes a single argument which must be a bytes
string with length 64.

    Note that some libraries prefix the byte serialized public key with
    a leading ``\x04`` byte which must be removed before use with the
    ``PublicKey`` object.

The following methods are available:

``PublicKey.from_private(private_key) -> PublicKey``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This ``classmethod`` returns a new ``PublicKey`` instance computed from
the given ``private_key``.

-  ``private_key`` may either be a byte string of length 32 or an
   instance of the ``KeyAPI.PrivateKey`` class.

``PublicKey.recover_from_msg(message, signature) -> PublicKey``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This ``classmethod`` returns a new ``PublicKey`` instance computed from
the provided ``message`` and ``signature``.

-  ``message`` **must** be a byte string
-  ``signature`` **must** be an instance of ``KeyAPI.Signature``

``PublicKey.recover_from_msg_hash(message_hash, signature) -> PublicKey``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Same as ``PublicKey.recover_from_msg`` except that ``message_hash``
should be the Keccak hash of the ``message``.

``PublicKey.verify_msg(message, signature) -> bool``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This method returns ``True`` or ``False`` based on whether the signature
is a valid for the given message.

``PublicKey.verify_msg_hash(message_hash, signature) -> bool``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Same as ``PublicKey.verify_msg`` except that ``message_hash`` should be
the Keccak hash of the ``message``.

``PublicKey.to_address() -> text``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Returns the hex encoded ethereum address for this public key.

``PublicKey.to_checksum_address() -> text``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Returns the ERC55 checksum formatted ethereum address for this public
key.

``PublicKey.to_canonical_address() -> bytes``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Returns the 20-byte representation of the ethereum address for this
public key.

``KeyAPI.PrivateKey(private_key_bytes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``PrivateKey`` class takes a single argument which must be a bytes
string with length 32.

The following methods and properties are available

``PrivateKey.public_key``
^^^^^^^^^^^^^^^^^^^^^^^^^

This *property* holds the ``PublicKey`` instance coresponding to this
private key.

``PrivateKey.sign_msg(message) -> Signature``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This method returns a signature for the given ``message`` in the form of
a ``Signature`` instance

-  ``message`` **must** be a byte string.

``PrivateKey.sign_msg_hash(message_hash) -> Signature``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Same as ``PrivateKey.sign`` except that ``message_hash`` should be the
Keccak hash of the ``message``.

``KeyAPI.Signature(signature_bytes=None, vrs=None)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``Signature`` class can be instantiated in one of two ways.

-  ``signature_bytes``: a bytes string with length 65.
-  ``vrs``: a 3-tuple composed of the integers ``v``, ``r``, and ``s``.

    Note: If using the ``signature_bytes`` to instantiate, the byte
    string should be encoded as ``r_bytes | s_bytes | v_bytes`` where
    ``|`` represents concatenation. ``r_bytes`` and ``s_bytes`` should
    be 32 bytes in length. ``v_bytes`` should be a single byte ``\x00``
    or ``\x01``.

Signatures are expected to use ``1`` or ``0`` for their ``v`` value.

The following methods and properties are available

``Signature.v``
^^^^^^^^^^^^^^^

This property returns the ``v`` value from the signature as an integer.

``Signature.r``
^^^^^^^^^^^^^^^

This property returns the ``r`` value from the signature as an integer.

``Signature.s``
^^^^^^^^^^^^^^^

This property returns the ``s`` value from the signature as an integer.

``Signature.vrs``
^^^^^^^^^^^^^^^^^

This property returns a 3-tuple of ``(v, r, s)``.

``Signature.verify_msg(message, public_key) -> bool``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This method returns ``True`` or ``False`` based on whether the signature
is a valid for the given public key.

-  ``message``: **must** be a byte string.
-  ``public_key``: **must** be an instance of ``PublicKey``

``Signature.verify_msg_hash(message_hash, public_key) -> bool``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Same as ``Signature.verify_msg`` except that ``message_hash`` should be
the Keccak hash of the ``message``.

``Signature.recover_public_key_from_msg(message) -> PublicKey``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This method returns a ``PublicKey`` instance recovered from the
signature.

-  ``message``: **must** be a byte string.

``Signature.recover_public_key_from_msg_hash(message_hash) -> PublicKey``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Same as ``Signature.recover_public_key_from_msg`` except that
``message_hash`` should be the Keccak hash of the ``message``.

Exceptions
~~~~~~~~~~

``eth_api.exceptions.ValidationError``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This error is raised during instantaition of any of the ``PublicKey``,
``PrivateKey`` or ``Signature`` classes if their constructor parameters
are invalid.

``eth_api.exceptions.BadSignature``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This error is raised from any of the ``recover`` or ``verify`` methods
involving signatures if the signature is invalid.


