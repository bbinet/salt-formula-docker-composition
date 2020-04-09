{%- if pillar.docker-composition is defined %}
include:
- docker-composition.generic
- docker-composition.traefik_v1
- docker-composition.hig
{%- endif %}
