FROM redis
MAINTAINER Huy Doan <me@huy.im>

ENV DEBIAN_FRONTEND noninteractive
ENV ONE_DIR=0

# Packages
RUN apt-get update -q && apt-get dist-upgrade -y -q && apt-get install -y -q wget gnupg2
RUN echo 'deb http://xi.dovecot.fi/debian/ stable-auto/dovecot-2.2 main' > /etc/apt/sources.list.d/dovecot.list && \
    echo 'deb-src http://xi.dovecot.fi/debian/ stable-auto/dovecot-2.2 main' >> /etc/apt/sources.list.d/dovecot.list
RUN wget -O- https://rspamd.com/apt-stable/gpg.key | apt-key add -
RUN wget -O - http://xi.dovecot.fi/debian/archive.key | apt-key add -
RUN echo "deb http://rspamd.com/apt-stable/ jessie main" > /etc/apt/sources.list.d/rspamd.list && \
    echo "deb-src http://rspamd.com/apt-stable/ jessie main" >> /etc/apt/sources.list.d/rspamd.list
RUN apt-get -q update && apt-get -y -q --no-install-recommends install \
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
    python-markdown \
    python-m2crypto \
    python-requests \
    rspamd \
    rsyslog

# Configure GPG-Mailgate
RUN mkdir -p /var/gpgmailgate/smime

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
COPY ./target/usr /usr

# Helper scripts
RUN chmod +x /usr/local/bin/*

EXPOSE 25 587 993 11334
VOLUME ["/var/mail", "/var/mail-state"]

CMD /usr/local/bin/start-server.sh