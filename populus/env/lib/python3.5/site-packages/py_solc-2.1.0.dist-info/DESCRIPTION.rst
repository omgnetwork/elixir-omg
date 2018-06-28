py-solc
=======

|Build Status| |PyPi version| |PyPi downloads|

Python wrapper around the ``solc`` Solidity compiler.

Dependency
----------

This library requires the ``solc`` executable to be present.

Only versions ``>=0.4.2`` are supported and tested though this library
may work with other versions.

`solc installation
instructions <http://solidity.readthedocs.io/en/latest/installing-solidity.html>`__

Quickstart
----------

Installation

.. code:: sh

    pip install py-solc

Development
-----------

Clone the repository and then run:

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

Standard JSON Compilation
-------------------------

Use the ``solc.compile_standard`` function to make use the
[standard-json] compilation feature.

`Solidity Documentation for Standard JSON input and ouptup
format <http://solidity.readthedocs.io/en/develop/using-the-compiler.html#compiler-input-and-output-json-description>`__

::

    >>> from solc import compile_standard
    >>> compile_standard({
    ...     'language': 'Solidity',
    ...     'sources': {'Foo.sol': 'content': "...."},
    ... })
    {
        'contracts': {...},
        'sources': {...},
        'errors': {...},
    }
    >>> compile_standard({
    ...     'language': 'Solidity',
    ...     'sources': {'Foo.sol': 'urls': ["/path/to/my/sources/Foo.sol"]},
    ... }, allow_paths="/path/to/my/sources")
    {
        'contracts': {...},
        'sources': {...},
        'errors': {...},
    }

Legacy Combined JSON compilation
--------------------------------

.. code:: python

    >>> from solc import compile_source, compile_files, link_code
    >>> compile_source("contract Foo { function Foo() {} }")
    {
        'Foo': {
            'abi': [{'inputs': [], 'type': 'constructor'}],
            'code': '0x60606040525b5b600a8060126000396000f360606040526008565b00',
            'code_runtime': '0x60606040526008565b00',
            'source': None,
            'meta': {
                'compilerVersion': '0.3.5-9da08ac3',
                'language': 'Solidity',
                'languageVersion': '0',
            },
        },
    }
    >>> compile_files(["/path/to/Foo.sol", "/path/to/Bar.sol"])
    {
        'Foo': {
            'abi': [{'inputs': [], 'type': 'constructor'}],
            'code': '0x60606040525b5b600a8060126000396000f360606040526008565b00',
            'code_runtime': '0x60606040526008565b00',
            'source': None,
            'meta': {
                'compilerVersion': '0.3.5-9da08ac3',
                'language': 'Solidity',
                'languageVersion': '0',
            },
        },
        'Bar': {
            'abi': [{'inputs': [], 'type': 'constructor'}],
            'code': '0x60606040525b5b600a8060126000396000f360606040526008565b00',
            'code_runtime': '0x60606040526008565b00',
            'source': None,
            'meta': {
                'compilerVersion': '0.3.5-9da08ac3',
                'language': 'Solidity',
                'languageVersion': '0',
            },
        },
    }
    >>> unlinked_code = "606060405260768060106000396000f3606060405260e060020a6000350463e7f09e058114601a575b005b60187f0c55699c00000000000000000000000000000000000000000000000000000000606090815273__TestA_________________________________90630c55699c906064906000906004818660325a03f41560025750505056"
    >>> link_code(unlinked_code, {'TestA': '0xd3cda913deb6f67967b99d67acdfa1712c293601'})
    ... "606060405260768060106000396000f3606060405260e060020a6000350463e7f09e058114601a575b005b60187f0c55699c00000000000000000000000000000000000000000000000000000000606090815273d3cda913deb6f67967b99d67acdfa1712c29360190630c55699c906064906000906004818660325a03f41560025750505056"

Setting the path to the ``solc`` binary
---------------------------------------

You can use the environment variable ``SOLC_BINARY`` to set the path to
your solc binary.

Installing the ``solc`` binary
------------------------------

    This feature is experimental and subject to breaking changes.

Any of the following versions of ``solc`` can be installed using
``py-solc`` on the listed platforms.

-  ``v0.4.1`` (linux)
-  ``v0.4.2`` (linux)
-  ``v0.4.6`` (linux)
-  ``v0.4.7`` (linux)
-  ``v0.4.8`` (linux/osx)
-  ``v0.4.9`` (linux)
-  ``v0.4.11`` (linux/osx)
-  ``v0.4.12`` (linux/osx)
-  ``v0.4.13`` (linux/osx)
-  ``v0.4.14`` (linux/osx)
-  ``v0.4.15`` (linux/osx)
-  ``v0.4.16`` (linux/osx)
-  ``v0.4.17`` (linux/osx)
-  ``v0.4.18`` (linux/osx)
-  ``v0.4.19`` (linux/osx)

Installation can be done via the command line:

.. code:: bash

    $ python -m solc.install v0.4.19

Or from python using the ``install_solc`` function.

.. code:: python

    >>> from solc import install_solc
    >>> install_solc('v0.4.19')

The installed binary can be found under your home directory. The
``v0.4.19`` binary would be located at
``$HOME/.py-solc/solc-v0.4.19/bin/solc``. Older linux installs will also
require that you set the environment variable
``LD_LIBRARY_PATH=$HOME/.py-solc/solc-v0.4.19/bin``

Import path remappings
----------------------

``solc`` provides path aliasing allow you to have more reusable project
configurations.

You can use this like:

::

    from solc import compile_source, compile_files, link_code

    compile_files([source_file_path], import_remappings=["zeppeling=/my-zeppelin-checkout-folder"])

`More information about solc import
aliasing <http://solidity.readthedocs.io/en/develop/layout-of-source-files.html#paths>`__

.. |Build Status| image:: https://travis-ci.org/ethereum/py-solc.png
   :target: https://travis-ci.org/ethereum/py-solc
.. |PyPi version| image:: https://pypip.in/v/py-solc/badge.png
   :target: https://pypi.python.org/pypi/py-solc
.. |PyPi downloads| image:: https://pypip.in/d/py-solc/badge.png
   :target: https://pypi.python.org/pypi/py-solc


