{%- from "docker-composition/map.jinja" import cfg, saltstack as composition with context %}
{%- set cname = 'saltstack' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- for master, mastercfg in composition.get('master', {}).iteritems() %}
{{ cpath }}/{{ master }}:
  file.directory:
    - makedirs: True
    - require_in:
      - file: {{ cpath }}
{{ cpath }}/{{ master }}/etc_salt_master.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ mastercfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require:
      - file: {{ cpath }}/{{ master }}
{%- endfor %}

{%- for minion, minioncfg in composition.get('minion', {}).iteritems() %}
{{ cpath }}/{{ minion }}:
  file.directory:
    - makedirs: True
    - require_in:
      - file: {{ cpath }}
{{ cpath }}/{{ minion }}/etc_salt_minion.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ minioncfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require:
      - file: {{ cpath }}/{{ minion }}
{%- endfor %}
{%- endblock main %}
