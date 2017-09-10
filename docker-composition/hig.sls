{%- from "docker-composition/map.jinja" import cfg, hig as composition with context %}
{%- set cname = 'hig' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- if composition.directory is defined %}
{%- for dir, dircfg in composition.directory.iteritems() %}

{# HINDSIGHT #}
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

{# KAPACITOR #}
{%- if dircfg.kapacitorconfig is defined %}
{%- set kapacitorconfig_influxdb = dircfg.kapacitorconfig.get('influxdb', {
    'default': {
        'enabled': True,
        'urls': "http://influxdb:8086",
    }
}) %}
{{ cpath }}/{{ dir }}/kapacitor.conf:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/kapacitor/kapacitor.conf
    - template: jinja
    - context:
        influxdbs: {{ kapacitorconfig_influxdb|json }}
        smtp: {{ dircfg.kapacitorconfig.get('smtp', {})|json }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}

{%- if dircfg.kapacitorconfig.tickscripts is defined %}
{%- for db, dbcfg in dircfg.kapacitorconfig.tickscripts.iteritems() %}
{%- for mc, mccfg in dbcfg.iteritems() %}
{%- for script, scriptcfg in mccfg.iteritems() %}
{{ cpath }}/{{ dir }}/{{ db }}/{{ mc }}/{{ script }}.tick:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/kapacitor/{{ scriptcfg.tick }}.tick
    - template: jinja
    - context:
        cfg: {{ scriptcfg.cfg|json }}
        db: {{ db }}
        mc: {{ mc }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}/{{ dir }}
{{ dir }}_{{ db }}_{{ mc }}_{{ script }}:
  kapacitor.task_present:
    - tick_script: {{ cpath }}/{{ dir }}/{{ db }}/{{ mc }}/{{ script }}.tick
    - task_type: batch
    - database: {{ db }}
    - retention_policy: autogen
    - enable: {{ scriptcfg.get('enable', False) }}

{%- endfor %}
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- endif %}


{%- endfor %}
{%- endif %}
{%- endblock main %}
