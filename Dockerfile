FROM redis
MAINTAINER Huy Doan <me@huy.im>

ENV DEBIAN_FRONTEND noninteractive
ENV ONE_DIR=0

# Packages
RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install -y wget gnupg2
RUN wget -O- https://rspamd.com/apt-stable/gpg.key | apt-key add -
RUN echo "deb http://rspamd.com/apt-stable/ jessie main" > /etc/apt/sources.list.d/rspamd.list
RUN echo "deb-src http://rspamd.com/apt-stable/ jessie main" >> /etc/apt/sources.list.d/rspamd.list
RUN apt-get update && apt-get -y --no-install-recommends install \
	cron \
    dovecot-imapd \
    dovecot-lmtpd \
    dovecot-managesieved \
    dovecot-sieve \
    fail2ban \
	git \
	iproute2 \
	libssl-dev \
    logwatch \
    postfix \
    python \
    python-m2crypto \
    rspamd \
    rsyslog

# Configure GPG-Mailgate
RUN mkdir -p /var/mail-state/.gnupg && mkdir -p /var/gpgmailgate/smime && usermod -d /var/gpgmailgate nobody

RUN git clone --depth=1 https://github.com/rgv151/gpg-mailgate.git /tmp/gpg-mailgate && \
  mv /tmp/gpg-mailgate/gpg-mailgate.py /tmp/gpg-mailgate/register-handler.py /usr/local/bin/ && \
  mv /tmp/gpg-mailgate/register_templates /var/gpgmailgate/ && \
  chown -R nobody:nogroup /var/gpgmailgate && \
  chown nobody:nogroup /usr/local/bin/gpg-mailgate.py && \
  chown nobody:nogroup /usr/local/bin/register-handler.py && \
  mv /tmp/gpg-mailgate/GnuPG /usr/local/lib/python2.7/dist-packages && rm -rf /tmp/gpg-mailgate
RUN echo 'register: "|/usr/local/bin/register-handler.py"' >> /etc/aliases && newaliases

RUN apt-get -y --purge remove \
	git \
	libssl-dev \
	&& apt-get autoremove -y --purge && apt-get clean
 
RUN openssl dhparam -out /etc/postfix/dhparams.pem 2048

# Configures Dovecot
RUN sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf
RUN sed -i -e 's/#mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins sieve/g' /etc/dovecot/conf.d/15-lda.conf
RUN sed -i -e 's/^.*lda_mailbox_autocreate.*/lda_mailbox_autocreate = yes/g' /etc/dovecot/conf.d/15-lda.conf
RUN sed -i -e 's/^.*lda_mailbox_autosubscribe.*/lda_mailbox_autosubscribe = yes/g' /etc/dovecot/conf.d/15-lda.conf
RUN sed -i -e 's/^.*postmaster_address.*/postmaster_address = '${POSTMASTER_ADDRESS:="postmaster@domain.com"}'/g' /etc/dovecot/conf.d/15-lda.conf
RUN sed -i 's/#imap_idle_notify_interval = 2 mins/imap_idle_notify_interval = 29 mins/' /etc/dovecot/conf.d/20-imap.conf
RUN cd /usr/share/dovecot && ./mkcert.sh
RUN mkdir /usr/lib/dovecot/sieve-pipe && chmod 755 /usr/lib/dovecot/sieve-pipe
RUN mkdir /usr/lib/dovecot/sieve-filter && chmod 755 /usr/lib/dovecot/sieve-filter

COPY ./target/bin /usr/local/bin
COPY ./target/etc /etc

# Helper scripts
RUN chmod +x /usr/local/bin/*
RUN sysctl vm.overcommit_memory=1

EXPOSE 25 587 993 11334
VOLUME ["/var/mail", "/var/mail-state"]

CMD /usr/local/bin/start-server.sh