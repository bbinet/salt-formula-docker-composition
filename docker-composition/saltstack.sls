{%- from "docker-composition/map.jinja" import cfg, saltstack with context %}
{%- if saltstack.enabled and saltstack.compose is defined %}

{{ cfg.base }}/compose/saltstack:
  file.directory:
    - makedirs: True
    - clean: True

{{ cfg.base }}/compose/saltstack/docker-compose.yml:
  file.managed:
    # docker-compose cfg is managed in pillar so it is easily overridable
    - contents: |
        {{ saltstack.compose | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/compose/saltstack

{%- for master, mastercfg in saltstack.get('master', {}).iteritems() %}
{{ cfg.base }}/compose/saltstack/{{ master }}:
  file.directory:
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/compose/saltstack
{{ cfg.base }}/compose/saltstack/{{ master }}/etc_salt_master.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ mastercfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require:
      - file: {{ cfg.base }}/compose/saltstack/{{ master }}
{{ cfg.base }}/compose/saltstack/{{ master }}/etc_salt_master.d/certs:
  file.directory:
    - makedirs: True
    - clean: True
    - require:
      - file: {{ cfg.base }}/compose/saltstack/{{ master }}
{%- for crt, key in mastercfg.get('certs', {}) %}
{{ cfg.base }}/compose/saltstack/{{ master }}/etc_salt_master.d/certs/{{ crt }}:
  file.managed:
    - mode: 400
    - dir_mode: 700
    - contents: |
        {{ key | indent(8) }}
    - makedirs: True
    - require:
      - file: {{ cfg.base }}/compose/saltstack/{{ master }}/etc_salt_master.d/certs
{%- endfor %}
{%- endfor %}

{%- for minion, minioncfg in saltstack.get('minion', {}).iteritems() %}
{{ cfg.base }}/compose/saltstack/{{ minion }}:
  file.directory:
    - makedirs: True
    - require_in:
      - file: {{ cfg.base }}/compose/saltstack
{{ cfg.base }}/compose/saltstack/{{ minion }}/etc_salt_minion.d/helioslite.conf:
  file.managed:
    - contents: |
        {{ minioncfg.get('conf', {}) | yaml(False) | indent(8) }}
    - contents_newline: True
    - makedirs: True
    - require:
      - file: {{ cfg.base }}/compose/saltstack/{{ minion }}
{%- endfor %}
{#
{%- for hooked, hookedcfg in saltstack.get('hooked-git-workdir', {}).iteritems() %}
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked:
  file.directory:
    - makedirs: True
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked/id_rsa:
  file.managed:
    - contents: |
        {{ hookedcfg.certs.id_rsa | indent(8) }}
    - mode: 0400
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked/id_rsa.pub:
  file.managed:
    - contents: |
        {{ hookedcfg.certs.id_rsa_pub | indent(8) }}
    - mode: 0600
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked/git_ssh:
  file.managed:
    - source: salt://docker-composition/files/saltstack/hooked-git-workdir/git_ssh
    - mode: 0755
    - template: jinja
    - context:
        config_dir: {{ hookedcfg.config_dir }}
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked/before-exec.sh:
  file.managed:
    - source: salt://docker-composition/files/saltstack/hooked-git-workdir/before-exec.sh
    - mode: 0755
    - template: jinja
    - context:
        config_dir: {{ hookedcfg.config_dir }}
        git_repo_path: {{ hookedcfg.git_repo_path }}
        git_workdir_path: {{ hookedcfg.git_workdir_path }}
        git_ssh: {{ hookedcfg.git_ssh }}
{{ cfg.base }}/compose/saltstack/{{ hooked }}/etc_hooked/pull-all-branches.sh:
  file.managed:
    - source: salt://docker-composition/files/saltstack/hooked-git-workdir/pull-all-branches.sh
    - mode: 0755
    - template: jinja
    - context:
        git_repo_path: {{ hookedcfg.git_repo_path }}
{%- endfor %}
#}
{%- endif %}
