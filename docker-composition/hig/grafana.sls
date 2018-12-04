{%- from "docker-composition/map.jinja" import cfg with context %}

{%- set ctype = 'hig' %}

{%- for cname, composition in salt['pillar.get']('docker-composition', {}).iteritems() %}

{%- if composition is mapping and composition.get('enabled') and composition.get('type') == ctype %}

{%- if composition.custom is defined %}
{%- for cus, cuscfg in composition.custom.iteritems() %}
{%- if cuscfg.grafana is defined %}

{#{%- set profile = 'docker-composition:' + cname + ':custom:' + cus + ':grafana:client' %}#}
{%- set client = cuscfg.grafana.get('client') %}


{%- for name, user in cuscfg.grafana.get('users', {}).items() %}
grafana4_user_{{ name }}:
  {%- if user %}
  grafana4_user.present:
    - name: "{{ name }}"
    - password: "{{ user.password }}"
    - email: "{{ user.email }}"
    - is_admin: {{ user.get('is_admin', False) }}
    {%- for item in ('fullname', 'theme') %}
    {%- if item in user %}
    - {{ item }}: "{{ user[item] }}"
    {%- endif %}
    {%- endfor %}
  {%- else %}
  grafana4_user.absent:
    - name: "{{ name }}"
  {%- endif %}
      {%- if client %}
    - profile: {{ client | json }}
      {%- endif %}
{%- endfor %}

{%- for orgname, org in cuscfg.grafana.get('orgs', {}).items() %}
grafana4_org_{{ orgname }}:
  {%- if org %}
  {%- set org = dict(cuscfg.grafana | traverse('defaults:org', {}), **org) %}
  grafana4_org.present:
    - name: "{{ orgname }}"
    {%- for item in ('theme', 'timezone', 'home_dashboard_id', 'address1', 'address2', 'city', 'zip_code', 'address_state', 'country') %}
    {%- if item in org %}
    - {{ item }}: "{{ org[item] }}"
    {%- endif %}
    {%- endfor %}
    {%- set users = {} %}
    {%- for team in org.get('teams', []) %}
      {%- do users.update(cuscfg.grafana | traverse('teams:%s' % team, {})) %}
    {%- endfor %}
    {%- do users.update(org.get('users', {})) %}
    - users: {{ users | json }}
  {%- else %}
  grafana4_org.absent:
    - name: "{{ orgname }}"
  {%- endif %}
      {%- if client %}
    - profile: {{ client | json }}
      {%- endif %}
{%- for name, ds in org.get('datasources', {}).items() %}
grafana4_datasource_{{ orgname }}_{{ name }}:
  {%- if ds %}
    {%- if ds is string %}
    {%- set db_name = ds.split(':')[-1] %}
    {%- set ds = dict(
          cuscfg.grafana | traverse('defaults:datasource', {}),
          database=db_name,
          user=db_name + '_ro',
          password=salt['pillar.get'](ds)['ro_password'],
          ) %}
    {%- else %}
    {%- set ds = dict(cuscfg.grafana | traverse('defaults:datasource', {}), **ds) %}
    {%- endif %}
  grafana4_datasource.present:
    - name: {{ name }}
    - type: "{{ ds.type }}"
    - url: "{{ ds.url }}"
    {%- for item in ('database', 'user', 'password', 'access', 'basic_auth_user', 'basic_auth_password') %}
    {%- if item in ds %}
    - {{ item }}: "{{ ds[item] }}"
    {%- endif %}
    {%- endfor %}
    - basic_auth: {{ ds.get('basic_auth', False) }}
    - is_default: {{ ds.get('is_default', False) }}
    - orgname: {{ orgname }}
  {%- else %}
  grafana4_datasource.absent:
    - name: {{ name }}
    - orgname: {{ orgname }}
  {%- endif %}
      {%- if client %}
    - profile: {{ client | json }}
      {%- endif %}
    - require:
      - grafana4_org: grafana4_org_{{ orgname }}
{%- endfor %}
{%- for name, dash in org.get('dashboards', {}).items() %}
grafana4_dashboard_{{ orgname }}_{{ name }}:
  {%- if dash %}
    {%- if dash is string %}
      {%- set dash = cuscfg.grafana | traverse('dashboards:%s'% dash) %}
    {%- endif %}
  grafana4_dashboard.present:
    - name: {{ name | lower }}
    {%- if dash.type == 'file' %}
    {%- import_json dash.data as dashboard %}
    - dashboard: {{ dashboard | json }}
    {%- elif dash.type == 'hlonnet' %}
{%- set hlonnet = dash %}
{%- set panels_cfg = hlonnet.get('panels', {}) %}
{%- if hlonnet.get('inherit') %}
  {%- set hlonnet = dict(cuscfg.grafana | traverse('dashboards:%s'% hlonnet.inherit, {}), **hlonnet) %}
  {%- set panels_cfg = dict(cuscfg.grafana | traverse('dashboards:%s:panels'% hlonnet.inherit, {}), **hlonnet.get('panels', {})) %}
{%- endif %}
{%- set panels = [] %}
{%- for _, line in panels_cfg | dictsort %}
  {%- if line %}
    {%- do panels.append(line) %}
  {%- endif %}
{%- endfor %}
{%- set hl = "
local hl = import 'hlonnet/helioslite.libsonnet';
hl.dashboard.new(
  '%s',
  refresh='%s',
  editable=%s,
  time_from='%s',
  tags=%r,
  templates=%r,
  annotations=%r,
  panels=%r,
  h=%d,
)" % (
  name,
  hlonnet.get('refresh', '1m'),
  "true" if hlonnet.editable else "false",
  hlonnet.get('time_from', 'now-2d'),
  hlonnet.get('tags', ['helioslite', 'generated']),
  hlonnet.get('templates', []),
  hlonnet.get('annotations', []),
  panels,
  hlonnet.get('height', 8),
  ) %}
{%- set jsonnet_lpaths = [] %}
{%- for lp in cuscfg.grafana | traverse('jsonnet.library_paths', salt['config.option']('jsonnet.library_paths', [])) %}
  {%- do jsonnet_lpaths.append(lp if lp.startswith('/') else '/'.join([cfg.base, lp])) %}
{%- endfor %}
    - dashboard: {{ salt['jsonnet.evaluate'](hl, jsonnet_lpaths) | json }}
    {%- elif dash.type == 'jsonnet' %}
{%- set jsonnet_lpaths = [] %}
{%- for lp in cuscfg.grafana | traverse('jsonnet.library_paths', salt['config.option']('jsonnet.library_paths', [])) %}
  {%- do jsonnet_lpaths.append(lp if lp.startswith('/') else '/'.join([cfg.base, lp])) %}
{%- endfor %}
    - dashboard: {{ salt['jsonnet.evaluate'](dash.data) | json }}
    {%- elif dash.type == 'yaml' %}
    - dashboard: {{ dash.data | json }}
      {%- for item in ('base_dashboards_from_pillar', 'base_panels_from_pillar', 'base_rows_from_pillar') %}
        {%- if item in dash %}
    - {{ item }}: {{ dash[item] }}
        {%- endif %}
      {%- endfor %}
    {%- endif %}
  {%- else %}
  grafana4_dashboard.absent:
    - name: {{ name | lower }}
  {%- endif %}
      {%- if client %}
    - profile: {{ client | json }}
      {%- endif %}
    - orgname: {{ orgname }}
    - require:
      - grafana4_org: grafana4_org_{{ orgname }}
{%- endfor %}
{%- endfor %}

{%- endif %}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- endfor %}
