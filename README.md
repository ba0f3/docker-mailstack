## Set password for Rspamd
```sh
docker run -ti --rm mail rspamadm pw
```

## Create account
```sh
docker run --rm \
  -e MAIL_USER=test@mail.domain.com \
  -e MAIL_PASS=mypassword \
  -ti mail \
  /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' > config/postfix-accounts.cf
```