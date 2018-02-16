{%- if pillar.docker-composition is defined %}
include:
- docker-composition.generic
- docker-composition.traefik
- docker-composition.hig
{%- endif %}
