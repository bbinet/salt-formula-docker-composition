{%- from "docker-composition/map.jinja" import cfg, registry as composition with context %}
{%- set cname = 'registry' %}
{%- set cpath = cfg.base + '/compose/' + cname %}
{%- extends "docker-composition/default.jinja" %}

{%- block main %}
{%- endblock main %}
