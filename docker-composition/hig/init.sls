{%- set ctype = 'hig' %}

{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- if composition.directory is defined %}
{%- for dir, dircfg in composition.directory.iteritems() %}
{%- if dircfg.hsconfig is defined %}
{{ cpath }}/{{ dir }}/etc_hindsight/hindsight.cfg:
  file.managed:
    - source: salt://docker-composition/files/{{ ctype }}/hindsight/hindsight.cfg
    - template: jinja
    - context:
      hs: {{ dircfg.hsconfig|json }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}

{{ cpath }}/{{ dir }}/etc_hindsight/modules:
  file.directory:
    - makedirs: True
    - clean: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}

{%- set plugin = salt['slsutil.update']({"input": {}, "analysis": {}, "output": {}, "module": {}}, dircfg.get('plugin', {})) %}
{%- for mname, mcfg in plugin.module.iteritems() %}
  {%- if mcfg and mcfg.get('source_lua') %}
{{ cpath }}/{{ dir }}/etc_hindsight/modules/{{ mname }}.lua:
  file.managed:
    - source: {{ mcfg.source_lua }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/modules
  {%- endif %}
{%- endfor %}

{%- for ptype in ['input', 'analysis', 'output'] %}
{{ cpath }}/{{ dir }}/etc_hindsight/load/{{ ptype }}:
  file.directory:
    - makedirs: True
    - clean: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/hindsight.cfg
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}:
  file.directory:
    - makedirs: True
    - clean: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/hindsight.cfg

{%- for pname, pcfg in plugin[ptype].iteritems() %}
  {%- if pcfg and pcfg.get('source_lua') %}
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}/{{ pname }}.lua:
  file.managed:
    - source: {{ pcfg.source_lua }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}
  {%- endif %}
{%- endfor %}

{%- set plugins = salt['slsutil.update']({"input": {}, "analysis": {}, "output": {}}, dircfg.hsconfig.get('plugins', {})) %}
{%- for cfgname, cfg in plugins[ptype].iteritems() if cfg != False %}
{%- set pname = cfg.get('lua_plugin', cfgname) %}
{%- set pcfg = plugin[ptype][pname] %}
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}/{{ cfgname }}.cfg:
  file.managed:
    - source: {{ pcfg.source_cfg }}
    - template: jinja
    - makedirs: True
    - context:
      cfg: {{ cfg|json }}
    - require_in:
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}
{%- endfor %}

{%- endfor %}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- endblock main %}
