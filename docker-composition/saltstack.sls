{%- from "docker-composition/map.jinja" import cfg, saltstack with context %}
{%- if saltstack.enabled and saltstack.compose is defined %}

{{ cfg.base }}/saltstack/docker-compose.yml:
  file.managed:
    # docker-compose cfg is managed in pillar so it is easily overridable
    - contents: |
        {{ saltstack.compose | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True

{%- for master, mastercfg in saltstack.get('master', {}).iteritems() %}
{{ cfg.base }}/saltstack/{{ master }}/etc_salt_master.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ mastercfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
{{ cfg.base }}/saltstack/{{ master }}/etc_salt_master.d/certs:
  file.directory:
    - makedirs: True
    - clean: True
{%- for crt, key in mastercfg.get('certs', {}) %}
{{ cfg.base }}/saltstack/{{ master }}/etc_salt_master.d/certs/{{ crt }}:
  file.managed:
    - mode: 400
    - dir_mode: 700
    - contents: |
        {{ key | indent(8) }}
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/saltstack/{{ master }}/etc_salt_master.d/certs
{%- endfor %}
{%- endfor %}

{%- for minion, minioncfg in saltstack.get('minion', {}).iteritems() %}
{{ cfg.base }}/saltstack/{{ minion }}/etc_salt_minion.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ minioncfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
{%- endfor %}

{%- endif %}
