{%- if pillar.docker-composition is defined %}
include:
{%- if pillar.docker-composition.traefik is defined %}
- docker-composition.traefik
{%- endif %}
{%- if pillar.docker-composition.saltstack is defined %}
- docker-composition.saltstack
{%- endif %}
{%- if pillar.docker-composition.hig is defined %}
- docker-composition.hig
{%- endif %}
{%- if pillar.docker-composition.rsm is defined %}
- docker-composition.rsm
{%- endif %}
{%- endif %}
