# -*- coding: utf-8 -*-
# vim: ft=yaml
---
mongodb:
  wanted:
    # choose what you want
    database:
      - mongod
      - mongos
      - dbtools
      - shell
    # gui: defaults.yaml ships `wanted.gui: []`. Robo 3T was
    # discontinued (host dead since 2022); macOS Compass is excluded
    # here so the Linux test isn't gated on darwin-only artifacts.
    connectors:
      # bi   # enterprise advanced subscription
      - kafka
    upstream_repo: false
  linux:
    altpriority: 10000
