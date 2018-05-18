========
toposort
========

Overview
========

Implements a topological sort algorithm.

>From `Wikipedia <http://en.wikipedia.org/wiki/Topological_sorting>`_:
In computer science, a topological sort (sometimes abbreviated topsort
or toposort) or topological ordering of a directed graph is a linear
ordering of its vertices such that for every directed edge uv from
vertex u to vertex v, u comes before v in the ordering.

Input data description
======================

The input to the toposort function is a dict describing the
dependencies among the input nodes. Each key is a dependent node, the
corresponding value is a set containing the dependent nodes.

Note that toposort does not care what the input node values mean: it
just compares them for equality. The examples here usually use
integers, but they could be any hashable type.

Typical usage
=============

The interpretation of the input data here is: If 2 depends on 11; 9
depends on 11, 8 and 10; 10 depends on 11 and 3 (and so on), then in what
order should we process the items such that all nodes are processed
before any of their dependencies?::

    >>> from toposort import toposort, toposort_flatten
    >>> list(toposort({2: {11},
    ...                9: {11, 8, 10},
    ...                10: {11, 3},
    ...                11: {7, 5},
    ...                8: {7, 3},
    ...               }))
    [{3, 5, 7}, {8, 11}, {2, 10}, {9}]

And the answer is: process 3, 5, and 7 (in any order); then process 8
and 11; then process 2 and 10; then process 9. Note that 3, 5, and 7
are returned first because they do not depend on anything. They are
then removed from consideration, and then 8 and 11 don't depend on
anything remaining. This process continues until all nodes are
returned, or a circular dependency is detected.

Circular dependencies
=====================

A circular dependency will raise a CyclicDependencyError, which is
derived from ValueError.  Here 1 depends on 2, and 2 depends on 1::

    >>> list(toposort({1: {2},
    ...                2: {1},
    ...               }))
    Traceback (most recent call last):
        ...
    toposort.CircularDependencyError: Circular dependencies exist among these items: {1:{2}, 2:{1}}

In addition, the 'data' attribute of the raised CyclicDependencyError
will contain a dict containing the subset of the input data involved
in the circular dependency.


Module contents
===============

``toposort(data)``

Returns an iterator describing the dependencies among nodes in the
input data. Each returned item will be a set. Each member of this set
has no dependencies in this set, or in any set previously returned.

``toposort_flatten(data, sort=True)``

Like toposort(data), except that it returns a list of all of the
depend values, in order. If sort is true, the returned nodes are sorted within
each group before they are appended to the result::

    >>> toposort_flatten({2: {11},
    ...                   9: {11, 8, 10},
    ...                   10: {11, 3},
    ...                   11: {7, 5},
    ...                   8: {7, 3},
    ...                  })
    [3, 5, 7, 8, 11, 2, 10, 9]

Note that this result is the same as the first example: ``[{3, 5, 7}, {8, 11}, {2, 10}, {9}]``,
except that the result is flattened, and within each set the nodes
are sorted.


Testing
=======

To test, run 'python setup.py test'. On python >= 3.0, this also runs the doctests.

Change log
==========

1.5 2016-10-24 Eric V. Smith
----------------------------

* When a circular dependency error is detected, raise a specific
  exception, CircularDependencyError, which is a subclass of
  ValueError.  The 'data' attribute of the exception will contain the
  data involved in the circular dependency (issue #2).  Thanks
  lilydjwg for the initial patch.

* To make building wheels easier, always require setuptools in
  setup.py (issue #5).

* Mark wheel as being universal, that is, supporting both Python 2.7
  and 3.x (issue #7).

1.4 2015-05-16 Eric V. Smith
----------------------------

* Removed 'test' package, so it won't get installed by bdist_*. It's still
  included in sdists.

* No code changes.

1.3 2015-05-15 Eric V. Smith
----------------------------

* Fixed change log date.

* No code changes.

1.2 2015-05-15 Eric V. Smith
----------------------------

* Changed RPM name to python3-toposort if running with python 3.

* No code changes.

1.1 2014-07-24 Eric V. Smith
----------------------------

* Release version 1.1. No code changes.

* Add a README.txt entry on running the test suite.

* Fix missing test/__init__.py in the sdist.

1.0 2014-03-14 Eric V. Smith
----------------------------

* Release version 1.0. The API is stable.

* Add MANIFEST.in to MANIFEST.in, so that it is created in the sdist
  (issue #1).

0.2 2014-02-11 Eric V. Smith
----------------------------

* Modify setup.py to produce a RPM name of python-toposort for bdist_rpm.

0.1 2014-02-10 Eric V. Smith
----------------------------

* Initial release.


