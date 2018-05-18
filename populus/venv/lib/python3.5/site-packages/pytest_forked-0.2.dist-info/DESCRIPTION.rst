pytest-forked: run each test in a forked subprocess
====================================================


.. warning::

	this is a extraction of the xdist --forked module,
	future maintenance beyond the bare minimum is not plannend until a new maintainer is found


* ``--forked``: (not available on Windows) run each test in a forked
  subprocess to survive ``SEGFAULTS`` or otherwise dying processes


Installation
-----------------------

Install the plugin with::

    pip install pytest-forked

or use the package in develope/in-place mode with
a checkout of the `pytest-forked repository`_ ::

   pip install -e .


Usage examples
---------------------

If you have tests involving C or C++ libraries you might have to deal
with tests crashing the process.  For this case you may use the boxing
options::

    py.test --forked

which will run each test in a subprocess and will report if a test
crashed the process.  You can also combine this option with
running multiple processes via pytest-xdist to speed up the test run
and use your CPU cores::

    py.test -n3 --forked

this would run 3 testing subprocesses in parallel which each
create new forked subprocesses for each test.


.. _`pytest-forked repository`: https://github.com/pytest-dev/pytest-forked

