{%- from "docker-composition/map.jinja" import cfg, traefik with context %}
{%- if traefik.enabled and traefik.compose is defined %}

{{ cfg.base }}/compose/traefik:
  file.directory:
    - makedirs: True
    - clean: True

{{ cfg.base }}/compose/traefik/docker-compose.yml:
  file.managed:
    # docker-compose cfg is managed in pillar so it is easily overridable
    - contents: |
        {{ traefik.compose | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/compose/traefik

{{ cfg.base }}/compose/traefik/traefik.toml:
  file.managed:
    - source: salt://docker-composition/files/traefik/traefik.toml
    - template: jinja
    - context:
        conf: {{ traefik.conf }}
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/compose/traefik
{%- endif %}
