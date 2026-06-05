mongodb-formula
===============

Formula for MongoDB on GNU/Linux and MacOS.


.. contents:: **Table of Contents**
   :depth: 1

General notes
-------------

See the full `SaltStack Formulas installation and usage instructions
<https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html>`_.  If you are interested in writing or contributing to formulas, please pay attention to the `Writing Formula Section
<https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html#writing-formulas>`_. If you want to use this formula, please pay attention to the ``FORMULA`` file and/or ``git tag``, which contains the currently released version. This formula is versioned according to `Semantic Versioning <http://semver.org/>`_.  See `Formula Versioning Section <https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html#versioning>`_ for more details.

Special notes
-------------

By default only MongoDB server component (`mongod`) is installed.  This behaviour is configurable via pillars.

.. code-block:: yaml

    mongodb:
      wanted:
        # choose what you want or everything
        database:
          - mongod
          - mongos
          - dbtools
          - shell
        # gui: keep as `[]` if you don't want a desktop GUI. Robo 3T
        # was discontinued; on macOS you can add `- compass`.
        gui: []
        connectors:
          # - bi   # MongoDB Enterprise Advanced subscription only
          - kafka

Configuration can be supplied in yaml. Note the per-component key
(``mongod``) - settings at ``database:`` level are ignored:

.. code-block:: yaml

    mongodb:
      pkg:
        database:
          mongod:
            version: 8.0.20
            config:
              # http://docs.mongodb.org/manual/reference/configuration-options
              storage:
                dbPath: /var/lib/mongodb/mongod
              replication:
                replSetName: "rs1"
              sharding:
                clusterRole: shardsvr
              net:
                bindIp: '0.0.0.0,::'
                port: 27018
            firewall:
              ports:
                - tcp/27017
                - tcp/27018
                - tcp/27019

On macOS targets the formula reads the GUI session user from the
``mongodb_console_user`` / ``mongodb_console_group`` grains provided by
``_grains/mongodb.py``. Sync custom grains once after first pulling the
formula::

    salt '*' saltutil.sync_grains

The MongoDB shell (``mongosh``) is **not** installed on macOS by this
formula. Upstream publishes mongosh only as a ``.zip`` for darwin, and
Salt's ``archive.extracted`` has no zip equivalent of
``--strip-components``, so the extraction layout can't be normalized
declaratively. Install it directly instead::

    brew install mongosh

Version pinning under repo install
----------------------------------

On Linux server platforms (Debian, Ubuntu, non-Amazon RHEL family),
the formula installs MongoDB from the official apt / yum repo. The
repo URL is pinned to the major-minor stream derived from
``mongodb:pkg:database:mongod:version`` (e.g. ``mongodb-org/8.0`` for
version ``8.0.20``), so the universe of installable packages is
constrained at the repo level - you can only get ``8.0.x`` from the
``8.0`` stream.

The ``version`` field is also passed to ``pkg.installed`` as the
version argument. dnf and apt do fuzzy prefix matching on it: bare
``8.0.20`` typically resolves to whichever build the repo currently
publishes (e.g. ``8.0.20-1.el8`` on RHEL 8).

For strict version-release pinning, override ``version`` in pillar
with the full package-manager version string::

    mongodb:
      pkg:
        database:
          mongod:
            version: '8.0.20-1.el8'   # RHEL 8 strict pin
            # version: '8.0.20'        # default - dnf fuzzy match

This only matters on repo-install platforms. On archive-install
platforms (Amazon Linux, macOS), the ``version`` value is substituted
into the archive URL via the ``VER`` placeholder - so a release suffix
there would break the URL. Don't mix the two semantics in one pillar.

Contributing to this repo
-------------------------

**Commit message formatting is significant!!**

Please see `How to contribute <https://github.com/saltstack-formulas/.github/blob/master/CONTRIBUTING.rst>`_ for more details.

Available metastates
--------------------

.. contents::
   :local:

``mongodb``
^^^^^^^^^^^

*Meta-state (This is a state that includes other states)*.

This installs the MongoDB solution.


``mongodb.install``
^^^^^^^^^^^^^^^^^^^

This state installs MongoDB components using the platform-appropriate
upstream source:

- Debian / Ubuntu and non-Amazon RHEL family (Rocky, Alma, Oracle, RHEL):
  MongoDB's official apt / yum repository (``mongodb-org-server``,
  ``mongodb-org-mongos``, ``mongodb-database-tools``).
- Amazon Linux and macOS: archive tarball extracted under
  ``/usr/local/mongodb/``.

The default per platform is set in ``mongodb/osfamilymap.yaml`` and can
be overridden per-component via pillar (e.g. ``mongodb:pkg:database:mongod:use_upstream``).

``mongodb.config``
^^^^^^^^^^^^^^^^^^

This state will apply mongodb service configuration (files).

``mongodb.service``
^^^^^^^^^^^^^^^^^^^

This state will start mongodb component services.

``mongodb.service.clean``
^^^^^^^^^^^^^^^^^^^^^^^^^

This state will stop mongodb component services.

``mongodb.config.clean``
^^^^^^^^^^^^^^^^^^^^^^^^

This state will remove mongodb service configuration (files).

``mongodb.clean``
^^^^^^^^^^^^^^^^^

This state will remove mongodb components on MacOS and GNU/Linux.


Testing
-------

Linux testing is done with ``kitchen-salt``.

Requirements
^^^^^^^^^^^^

* Ruby
* Docker

.. code-block:: bash

   $ gem install bundler
   $ bundle install
   $ bin/kitchen test [platform]

Where ``[platform]`` is the platform name defined in ``kitchen.yml``,
e.g. ``debian-9-2019-2-py3``.

``bin/kitchen converge``
^^^^^^^^^^^^^^^^^^^^^^^^

Creates the docker instance and runs the ``mongodb`` main state, ready for testing.

``bin/kitchen verify``
^^^^^^^^^^^^^^^^^^^^^^

Runs the ``inspec`` tests on the actual instance.

``bin/kitchen destroy``
^^^^^^^^^^^^^^^^^^^^^^^

Removes the docker instance.

``bin/kitchen test``
^^^^^^^^^^^^^^^^^^^^

Runs all of the stages above in one go: i.e. ``destroy`` + ``converge`` + ``verify`` + ``destroy``.

``bin/kitchen login``
^^^^^^^^^^^^^^^^^^^^^

Gives you SSH access to the instance for manual testing.
