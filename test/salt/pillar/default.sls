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
    gui:
      # Robo 3T was discontinued after Studio 3T acquisition; the
      # download host has been dead since 2022.
           {%- if grains.kernel|lower == 'darwin' %}
      - compass
           {%- endif %}
    connectors:
      # bi   # enterprise advanced subscription
      - kafka
    upstream_repo: false
  linux:
    altpriority: 10000
