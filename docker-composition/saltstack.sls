{%- from "docker-composition/map.jinja" import cfg, saltstack as composition with context %}
{%- set cname = 'saltstack' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- endblock main %}
