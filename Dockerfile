FROM debian:stretch-slim
MAINTAINER Huy Doan <me@huy.im>

ENV DEBIAN_FRONTEND noninteractive
ENV ONE_DIR=0

# Packages
RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install -y wget gnupg2
RUN wget -O- https://rspamd.com/apt-stable/gpg.key | apt-key add -
RUN echo "deb http://rspamd.com/apt-stable/ stretch main" > /etc/apt/sources.list.d/rspamd.list
RUN echo "deb-src http://rspamd.com/apt-stable/ stretch main" >> /etc/apt/sources.list.d/rspamd.list
RUN apt-get update && apt-get -y --no-install-recommends install \
	cron \
    dovecot-imapd \
    dovecot-sieve \
    fail2ban \
	git \
	iproute2 \
    logwatch \
    postfix \
    redis-server \
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
  mv /tmp/gpg-mailgate/GnuPG /usr/local/lib/python3.5/dist-packages && rm -rf /tmp/gpg-mailgate
RUN echo 'register: "|/usr/local/bin/register-handler.py"' >> /etc/aliases && newaliases

COPY ./target/bin /usr/local/bin
COPY ./target/etc /etc

# Start-mailserver script
RUN chmod +x /usr/local/bin/*

EXPOSE 25 587 993 11334
VOLUME ["/var/mail", "/var/mail-state"]

CMD /usr/local/bin/start-server.sh