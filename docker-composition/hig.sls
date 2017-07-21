{%- from "docker-composition/map.jinja" import cfg, hig as composition with context %}
{%- set cname = 'hig' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- if composition.directory is defined %}
{%- for dir, dircfg in composition.directory.iteritems() %}
{%- if dircfg.hsconfig is defined %}
{{ cpath }}/{{ dir }}/etc_hindsight/hindsight.cfg:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/hindsight/hindsight.cfg
    - template: jinja
    - context:
      hs: {{ dircfg.hsconfig|json }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}

{{ cpath }}/{{ dir }}/etc_hindsight/modules:
  file.recurse:
    - source: salt://docker-composition/files/{{ cname }}/hindsight/modules
    - clean: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}

{%- for ptype in ['input', 'analysis', 'output'] %}
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}:
  file.directory:
    - makedirs: True
    - clean: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/hindsight.cfg

{%- set plugins = [] %}
{%- if dircfg.hsconfig.plugins is defined %}
{%- for pname, cfg in dircfg.hsconfig.plugins.get(ptype, {}).iteritems() %}
{%- if cfg == False %}{%- continue %}{%- endif %}
{%- set plugin = cfg.get('lua_plugin', pname) %}
{%- if plugin not in plugins %}
  {%- do plugins.append(plugin) %}
{%- endif %}
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}/{{ pname }}.cfg:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/hindsight/run/{{ ptype }}/{{ plugin }}.cfg
    - template: jinja
    - makedirs: True
    - context:
      cfg: {{ cfg|json }}
    - require_in:
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}
{%- endfor %}
{%- endif %}
{%- for plugin in plugins %}
{{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}/{{ plugin }}.lua:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/hindsight/run/{{ ptype }}/{{ plugin }}.lua
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}/etc_hindsight/run/{{ ptype }}
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- endblock main %}
