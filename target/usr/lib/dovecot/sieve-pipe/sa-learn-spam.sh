#!/bin/sh
/usr/bin/rspamc -h localhost:11334 -P $RSPAMD_PASSWD learn_spam
