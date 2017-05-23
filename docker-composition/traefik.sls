{%- from "docker-composition/map.jinja" import cfg, traefik as composition with context %}
{%- set cname = 'traefik' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{{ cpath }}/traefik.toml:
  file.managed:
    - source: salt://docker-composition/files/{{ cname }}/traefik.toml
    - template: jinja
    - context:
        conf: {{ composition.conf }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}
{%- endblock main %}
