{%- if pillar.docker-composition is defined %}
include:
{%- if pillar.docker-composition.traefik is defined %}
- docker-composition.traefik
{%- endif %}
{%- if pillar.docker-composition.saltstack is defined %}
- docker-composition.saltstack
{%- endif %}
{%- endif %}
