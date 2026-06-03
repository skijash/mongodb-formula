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
        gui:
          - robo3t
          - compass
        connectors:
          - bi
          - kafka

Configuration can be supplied in yaml:

.. code-block:: yaml

    mongodb:
      pkg:
        database:
          version: 8.0.4
          archive:
            skip_verify: true
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
