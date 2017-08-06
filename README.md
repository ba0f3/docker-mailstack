## Set password for Rspamd
```sh
docker run -ti --rm mail rspamadm pw
```

## Create account
```sh
docker run --rm -ti mail addmailuser user@domain [password] >> config/postfix-accounts.cf
```