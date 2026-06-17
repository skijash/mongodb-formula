# -*- coding: utf-8 -*-
# vim: ft=sls

{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/map.jinja" import data as d with context %}
{%- from tplroot ~ "/libtofs.jinja" import files_switch with context %}
{%- set sls_config_users = tplroot ~ '.config.users' %}
{%- set sls_software_install = tplroot ~ '.install' %}
{%- set formula = d.formula %}

include:
  - {{ sls_config_users }}
  - {{ sls_software_install }}

    {%- if grains.kernel|lower == 'linux' %}
        {%- if d.wanted.disable_transparent_hugepages %}
            {# v8+ enables THP for the new TCMalloc per-CPU caches.
               Exception per MongoDB docs: RHEL/Oracle 8 on ppc64le/s390x
               and RHEL/Oracle/CentOS 9 on ppc64le still ship legacy
               TCMalloc, so THP stays disabled on those platforms. #}
            {%- set _osarch = grains.get('osarch', '') %}
            {%- set _osmajor = grains.get('osmajorrelease', 0)|int %}
            {%- set _legacy_tcmalloc =
                  grains.os_family == 'RedHat'
                  and (
                    (_osmajor == 8 and _osarch in ('ppc64le', 's390x'))
                    or (_osmajor == 9 and _osarch == 'ppc64le')
                  ) %}
            {%- set thp_mode = 'enable' if (d.get('mongo_major', 0) >= 8 and not _legacy_tcmalloc) else 'disable' %}
            {%- set thp_settings = d.thp_settings[thp_mode] %}
            {%- set thp_unit = '/etc/systemd/system/mongodb-thp.service' %}

{{ formula }}-service-running-thp-legacy-init-absent:
  file.absent:
    - name: /etc/init.d/disable-transparent-hugepages

{{ formula }}-service-running-thp-unit:
  file.managed:
    - name: {{ thp_unit }}
    - source: {{ files_switch(['mongodb-thp.service.jinja'],
                              lookup=formula ~ '-service-running-thp-unit')
              }}
    - mode: '0644'
    - user: root
    - group: root
    - template: jinja
    - context:
        mode: {{ thp_mode }}
        settings: {{ thp_settings|json }}
    - require:
      - sls: {{ sls_software_install }}
      - sls: {{ sls_config_users }}
      - file: {{ formula }}-service-running-thp-legacy-init-absent

{{ formula }}-service-running-thp-daemon-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: {{ formula }}-service-running-thp-unit

            {%- set thp_check_specs = [] %}
            {%- for path, value in thp_settings %}
                {%- do thp_check_specs.append('"' ~ path ~ '=' ~ value ~ '"') %}
            {%- endfor %}

{{ formula }}-service-running-thp-converge:
  cmd.run:
    # Reapply when any current value drifts from expected (e.g. tuned /
    # ktune flips THP behind our back). On a clean host every check
    # passes and the restart is skipped.
    - name: systemctl restart mongodb-thp.service
    - unless: |
        for spec in {{ thp_check_specs|join(' ') }}; do
          primary=${spec%%=*}
          want=${spec#*=}
          # mirror the unit's path expansion: check whichever THP base
          # exists. for non-THP specs the sed is a no-op and alt == primary.
          alt=$(echo "$primary" | sed 's|/transparent_hugepage/|/redhat_transparent_hugepage/|')
          for path in "$primary" "$alt"; do
            [ -r "$path" ] || continue
            cur=$(cat "$path")
            case "$path" in
              */enabled|*/defrag)
                cur=$(echo "$cur" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
                ;;
            esac
            [ "$cur" = "$want" ] || exit 1
          done
        done
    - require:
      - cmd: {{ formula }}-service-running-thp-daemon-reload

{{ formula }}-service-running-thp-enabled:
  service.enabled:
    - name: mongodb-thp.service
    - require:
      - cmd: {{ formula }}-service-running-thp-daemon-reload

        {%- endif %}

        {%- if d.wanted.firewall %}
{{ formula }}-service-running-firewall:
  pkg.installed:
    - name: firewalld
    - reload_modules: true
  service.running:
    - name: firewalld
    - onlyif: systemctl list-units | grep firewalld >/dev/null 2>&1
    - enable: True
        {%- endif %}
    {%- endif %}

    {%- for comp in d.componentypes %}
        {%- if comp in d.wanted and d.wanted is iterable and comp in d.pkg and d.pkg[comp] is mapping %}
            {%- for name,v in d.pkg[comp].items() %}
                {%- if name in d.wanted[comp] %}
                    {%- set software = d.pkg[comp][name] %}
                    {%- if 'service' in software and software['service'] is mapping %}
                        {%- set service = software['service'] %}
                        {%- set servicename = name if 'name' not in service else service.name %}
                        {%- if 'config' in software and software['config'] is mapping %}
                            {%- set config = software['config'] %}

                            {%- set service_files = [] %}
                            {%- if 'processManagement' in config and 'pidFilePath' in config['processManagement'] %}
                                {%- do service_files.append(config['processManagement']['pidFilePath']) %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-pidpath:
  file.directory:
    - name: {{ config['processManagement']['pidFilePath'] }}
    - user: {{ software['user'] }}
    - group: {{ software['group'] }}
    - dir_mode: '0775'
    - makedirs: True
    - require:
      - sls: {{ sls_config_users }}
      - sls: {{ sls_software_install }}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
    - recurse:
      - user
      - group
                                {%- if 'selinux' in d.wanted and d.wanted.selinux %}
  selinux.fcontext_policy_present:
    - name: '{{ config['processManagement']['pidFilePath'] }}(/.*)?'
    - sel_type: {{ name }}_var_t
    - require_in:
      - selinux: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied
                                {%- endif %}

                            {%- endif %}
                            {%- if 'storage' in config and 'dbPath' in config['storage'] %}
                                {%- do service_files.append(config['storage']['dbPath']) %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-datapath:
  file.directory:
    - name: {{ config['storage']['dbPath'] }}
    - user: {{ software['user'] }}
    - group: {{ software['group'] }}
    - dir_mode: '0775'
    - makedirs: True
    - recurse:
      - user
      - group
    - require:
      - sls: {{ sls_config_users }}
    - unless: test -d {{ config['storage']['dbPath'] }}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                                {%- if 'selinux' in d.wanted and d.wanted.selinux %}
  selinux.fcontext_policy_present:
    - name: '{{ config['storage']['dbPath'] }}(/.*)?'
    - sel_type: {{ name }}_var_lib_t
    - onchanges:
      - file: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-datapath
    - require_in:
      - selinux: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied
                                {%- endif %}

                            {%- endif %}
                            {%- if 'schema' in config and 'path' in config['schema'] %}
                                {%- do service_files.append(config['schema']['path']) %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-schemapath:
  file.directory:
    - name: {{ config['schema']['path'] }}
    - user: {{ software['user'] }}
    - group: {{ software['group'] }}
    - dir_mode: '0775'
    - makedirs: True
    - recurse:
      - user
      - group
    - require:
      - sls: {{ sls_config_users }}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                                {%- if 'selinux' in d.wanted and d.wanted.selinux %}
  selinux.fcontext_policy_present:
    - name: '{{ config['schema']['path'] }}(/.*)?'
    - sel_type: etc_t
    - require:
      - file: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-schemapath
    - require_in:
      - selinux: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied
                                {%- endif %}

                            {%- endif %}
                            {%- set path = '/var/log/mongodb/' ~ servicename ~ '.log' %}
                            {%- if 'systemLog' in config and 'destination' in config['systemLog'] %}
                                {%- if config['systemLog']['destination'] == 'file'  %}
                                    {%- if 'path' in config['systemLog'] %}
                                        {%- set path = config['systemLog']['path'] %}
                                    {%- endif %}
                                {%- endif %}
                            {%- endif %}
                            {%- do service_files.append(path) %}
                            {%- set logdir = path.rpartition('/')[0] or '/' %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-syslogpath:
  file.directory:
    - name: {{ logdir }}
    - user: {{ software['user'] }}
    - group: {{ software['group'] }}
    - dir_mode: '0775'
    - makedirs: True
    - require:
      - sls: {{ sls_config_users }}
    - recurse:
      - user
      - group

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-syslogfile:
  file.managed:
    - name: {{ path }}
    - user: {{ software['user'] }}
    - group: {{ software['group'] }}
    - mode: '0775'
    - create: true
    - replace: false
    - require:
      - file: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-syslogpath
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                            {%- if 'selinux' in d.wanted and d.wanted.selinux %}
  selinux.fcontext_policy_present:
    - name: '{{ logdir }}(/.*)?'
    - sel_type: {{ name }}_var_log_t
    - require_in:
      - selinux: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied
                            {%- endif %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-install-logrotate:
  file.managed:
    - name: /etc/logrotate.d/{{ formula }}_{{ name }}
    - unless: ls /etc/logrotate.d/{{ formula }}_{{ name }}
    - user: root
    - group: {{ 'wheel' if grains.os in ('MacOS',) else 'root' }}
    - mode: '0440'
    - makedirs: True
    - source: salt://{{ formula }}/files/default/logrotate.jinja
    - context:
        svc: {{ name }}
        pattern: {{ logdir }}
                 {%- if 'processManagement' in config and 'pidFilePath' in config['processManagement'] %}
        pidpath: {{ config['processManagement']['pidFilePath'] }}
                 {%- else %}
        pidpath: {{ '/var/run/{{ name }}.pid' }}
                 {%- endif %}
        days: 7
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                            {%- if 'selinux' in d.wanted and d.wanted.selinux %}
  selinux.fcontext_policy_present:
    - name: '/etc/logrotate.d/{{ formula }}_{{ svc }}(/.*)?'
    - sel_type: etc_t
    - require_in:
      - selinux: {{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied
    - recursive: True
                            {%- endif %}

                            {%- if 'selinux' in d.wanted and d.wanted.selinux %}
{{ formula }}-service-running-{{ comp }}-{{ servicename }}-selinux-applied:
  selinux.fcontext_policy_applied:
    - names: {{ service_files|json }}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                            {%- endif %}

                        {%- endif %}  {# config #}
                        {%- if grains.kernel == 'Linux' and d.wanted.firewall and 'firewall' in software %}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-firewall-present:
  firewalld.present:
    - name: public
    - ports: {{ software['firewall']['ports']|json }}
                            {%- if grains.kernel|lower == 'linux' %}
    - require:
      - pkg: {{ formula }}-service-running-firewall
      - service: {{ formula }}-service-running-firewall
                            {%- endif %}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}
                        {%- endif %}  {# firewall #}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}-unmasked:
  service.unmasked:
    - name: {{ servicename }}
    - onlyif:
       - {{ grains.kernel|lower == 'linux' }}
       - systemctl list-unit-files | grep {{ servicename }} >/dev/null 2>&1
    - require:
      - sls: {{ sls_software_install }}
      - sls: {{ sls_config_users }}
    - require_in:
      - service: {{ formula }}-service-running-{{ comp }}-{{ servicename }}

{{ formula }}-service-running-{{ comp }}-{{ servicename }}:
                        {%- if grains.kernel|lower == 'darwin' %}  {# service.running is buggy #}
  cmd.run:
    - names:
      - launchctl load /Library/LaunchAgents/{{ servicename }}.plist || true
      - launchctl start {{ servicename }}
                        {%- else %}
  service.running:
    - name: {{ servicename }}
    - enable: True
    - onlyif: systemctl list-unit-files | grep {{ servicename }} >/dev/null 2>&1
                        {%- endif %}
    - require:
      - sls: {{ sls_software_install }}
      - sls: {{ sls_config_users }}
                        {%- if grains.kernel|lower == 'linux'
                              and d.wanted.disable_transparent_hugepages
                              and comp == 'database' %}
      # block mongod/mongos start until THP converge has run, so the
      # process inherits the right kernel state on first boot.
      - cmd: {{ formula }}-service-running-thp-converge
                        {%- endif %}
                        {%- if 'config' in software and software['config'] is mapping %}
    - watch:
      - file: {{ formula }}-config-file-{{ servicename }}-file-managed
                        {%- endif %}

                    {%- endif %}           {# service #}
                {%- endif %}               {# wanted #}
            {%- endfor %}                  {# component #}
        {%- endif %}                       {# wanted #}
    {%- endfor %}                          {# components #}
