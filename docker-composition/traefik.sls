{%- set ctype = 'traefik' %}

{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{{ cpath }}/traefik.toml:
  file.managed:
    - source: salt://docker-composition/files/{{ ctype }}/traefik.toml
    - template: jinja
    - context:
        conf: {{ composition.conf | json }}
    - makedirs: True
    - require_in:
      - file: {{ cpath }}
{%- endblock main %}
