{%- set ctype = 'hig' %}

{%- for cname, composition in salt['pillar.get']('docker-composition', {}).iteritems() %}

{%- if composition is mapping and composition.get('enabled') and composition.get('type') == ctype %}

{%- if composition.custom is defined %}
{%- for cus, cuscfg in composition.custom.iteritems() %}
{%- if cuscfg.influxdb is defined %}

{%- set client = cuscfg.influxdb.get('client') %}

{%- for name, cfg in cuscfg.influxdb.get('databases', {}).items() %}
influxdb_database_{{ name }}:
  {%- if cfg %}
  influxdb_database.present:
    - name: "{{ name }}"
      {%- if client %}
    - influxdb_host: {{ client.influxdb_host }}
    - influxdb_port: {{ client.influxdb_port }}
    - influxdb_user: {{ client.influxdb_user }}
    - influxdb_password: {{ client.influxdb_password }}
      {%- endif %}
    {%- if cfg.get('ro_password', False) %}
influxdb_database_{{ name }}_user_{{ name }}_ro:
  influxdb_user.present:
    - name: "{{ name }}_ro"
    - password: "{{ cfg['ro_password'] }}"
    - grants:
        {{ name }}: read
      {%- if client %}
    - influxdb_host: {{ client.influxdb_host }}
    - influxdb_port: {{ client.influxdb_port }}
    - influxdb_user: {{ client.influxdb_user }}
    - influxdb_password: {{ client.influxdb_password }}
      {%- endif %}
    - require:
      - influxdb_database: influxdb_database_{{ name }}
    {%- endif %}
    {%- if cfg.get('rw_password', False) %}
influxdb_database_{{ name }}_user_{{ name }}_rw:
  influxdb_user.present:
    - name: "{{ name }}_rw"
    - password: "{{ cfg['rw_password'] }}"
    - grants:
        {{ name }}: write
    - require:
      - influxdb_database: influxdb_database_{{ name }}
    {%- endif %}
  {%- else %}
  influxdb_database.absent:
    - name: "{{ name }}"
  {%- endif %}
      {%- if client %}
    - influxdb_host: {{ client.influxdb_host }}
    - influxdb_port: {{ client.influxdb_port }}
    - influxdb_user: {{ client.influxdb_user }}
    - influxdb_password: {{ client.influxdb_password }}
      {%- endif %}
{%- endfor %}

{%- for name, user in cuscfg.influxdb.get('users', {}).items() %}
influxdb_user_{{ name }}:
  {%- if user %}
  influxdb_user.present:
    - name: "{{ name }}"
    - password: "{{ user['password'] }}"
    - admin: {{ user.get('admin', False) }}
    - grants: {{ user.get('grants', {}) | json }}
  {%- else %}
  influxdb_user.absent:
    - name: "{{ name }}"
  {%- endif %}
      {%- if client %}
    - influxdb_host: {{ client.influxdb_host }}
    - influxdb_port: {{ client.influxdb_port }}
    - influxdb_user: {{ client.influxdb_user }}
    - influxdb_password: {{ client.influxdb_password }}
      {%- endif %}
{%- endfor %}

{%- endif %}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- endfor %}
