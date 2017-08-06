## Set password for Rspamd
```sh
docker run -ti --rm mail rspamadm pw
```

## Create account
```sh
docker run --rm -ti -v `pwd`/config:/tmp/docker-mailstack mail addmailuser user@domain.com [password]
```