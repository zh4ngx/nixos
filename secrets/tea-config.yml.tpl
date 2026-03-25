logins:
  - name: codeberg
    url: https://codeberg.org
    token: {{ .codeberg_token }}
    default: true
    ssh_host: codeberg.org
    ssh_key: /home/andy/.ssh/id_ed25519
    insecure: false
    user: zh4ng
