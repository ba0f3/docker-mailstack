#!/bin/bash

##########################################################################
# >> DEFAULT VARS
#
# add them here.
# Example: DEFAULT_VARS["KEY"]="VALUE"
##########################################################################
declare -A DEFAULT_VARS
DEFAULT_VARS["RSPAMD_PASSWD"]="${RSPAMD_PASSWD:="s3cret"}"
DEFAULT_VARS["ENABLE_FAIL2BAN"]="${ENABLE_FAIL2BAN:="0"}"
DEFAULT_VARS["ENABLE_MANAGESIEVE"]="${ENABLE_MANAGESIEVE:="0"}"
DEFAULT_VARS["ENABLE_SASLAUTHD"]="${ENABLE_SASLAUTHD:="0"}"
DEFAULT_VARS["DMS_DEBUG"]="${DMS_DEBUG:="0"}"
DEFAULT_VARS["OVERRIDE_HOSTNAME"]="${OVERRIDE_HOSTNAME}"
##########################################################################
# << DEFAULT VARS
##########################################################################

##########################################################################
# >> GLOBAL VARS
#
# add your global script variables here.
#
# Example: KEY="VALUE"
##########################################################################
HOSTNAME="$(hostname -f)"
DOMAINNAME="$(hostname -d)"
##########################################################################
# << GLOBAL VARS
##########################################################################

##########################################################################
# >> REGISTER FUNCTIONS
#
# add your new functions/methods here.
#
# NOTE: position matters when registering a function in stacks. First in First out
# 		Execution Logic:
# 			> check functions
# 			> setup functions
# 			> fix functions
# 			> misc functions
# 			> start-daemons
#
# Example:
# if [ CONDITION IS MET ]; then
#   _register_{setup,fix,check,start}_{functions,daemons} "$FUNCNAME"
# fi
#
# Implement them in the section-group: {check,setup,fix,start}
##########################################################################
function register_functions() {
	notify 'taskgrp' 'Initializing setup'
	notify 'task' 'Registering check,setup,fix,misc and start-daemons functions'

	################### >> check funcs

	_register_check_function "_check_environment_variables"
	_register_check_function "_check_hostname"

	################### << check funcs

	################### >> setup funcs

	_register_setup_function "_setup_default_vars"

	_register_setup_function "_setup_dovecot"
	_register_setup_function "_setup_dovecot_local_user"
	
	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_setup_function "_setup_saslauthd"
	fi

	_register_setup_function "_setup_ssl"
	_register_setup_function "_setup_docker_permit"

	_register_setup_function "_setup_mailname"
	_register_setup_function "_setup_postfix_hostname"
	_register_setup_function "_setup_dovecot_hostname"

	_register_setup_function "_setup_postfix_sasl"
	_register_setup_function "_setup_postfix_override_configuration"
	_register_setup_function "_setup_postfix_sasl_password"
	_register_setup_function "_setup_security_stack"
	_register_setup_function "_setup_postfix_aliases"
	_register_setup_function "_setup_postfix_vhost"

	if [ "$ENABLE_POSTFIX_VIRTUAL_TRANSPORT" = 1  ]; then
		_register_setup_function "_setup_postfix_virtual_transport"
	fi

  _register_setup_function "_setup_environment"
  _register_setup_function "_setup_rspamd_passwd"
  _register_setup_function "_setup_dkim"


	################### << setup funcs

	################### >> fix funcs

	_register_fix_function "_fix_var_mail_permissions"
	_register_fix_function "_fix_rspamd_permissions"

	################### << fix funcs

	################### >> misc funcs

	_register_misc_function "_misc_save_states"

	################### << misc funcs

	################### >> daemon funcs

	_register_start_daemon "_start_daemons_cron"
	_register_start_daemon "_start_daemons_rsyslog"

	if [ "$ENABLE_ELK_FORWARDER" = 1 ]; then
		_register_start_daemon "_start_daemons_filebeat"
	fi

	if [ "$SMTP_ONLY" != 1 ]; then
		_register_start_daemon "_start_daemons_dovecot"
	fi

	_register_start_daemon "_start_daemons_postfix"

	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_start_daemon "_start_daemons_saslauthd"
	fi

	# care needs to run after postfix
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		_register_start_daemon "_start_daemons_fail2ban"
	fi

	_register_start_daemon "_start_daemons_redis"
	_register_start_daemon "_start_daemons_rspamd"
	################### << daemon funcs
}
##########################################################################
# << REGISTER FUNCTIONS
##########################################################################



# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>


##########################################################################
# >> CONSTANTS
##########################################################################
declare -a FUNCS_SETUP
declare -a FUNCS_FIX
declare -a FUNCS_CHECK
declare -a FUNCS_MISC
declare -a DAEMONS_START
declare -A HELPERS_EXEC_STATE
##########################################################################
# << CONSTANTS
##########################################################################


##########################################################################
# >> protected register_functions
##########################################################################
function _register_start_daemon() {
	DAEMONS_START+=($1)
	notify 'inf' "$1() registered"
}

function _register_setup_function() {
	FUNCS_SETUP+=($1)
	notify 'inf' "$1() registered"
}

function _register_fix_function() {
	FUNCS_FIX+=($1)
	notify 'inf' "$1() registered"
}

function _register_check_function() {
	FUNCS_CHECK+=($1)
	notify 'inf' "$1() registered"
}

function _register_misc_function() {
	FUNCS_MISC+=($1)
	notify 'inf' "$1() registered"
}
##########################################################################
# << protected register_functions
##########################################################################


function notify () {
	c_red="\e[0;31m"
	c_green="\e[0;32m"
	c_brown="\e[0;33m"
	c_blue="\e[0;34m"
	c_bold="\033[1m"
	c_reset="\e[0m"

	notification_type=$1
	notification_msg=$2
	notification_format=$3
	msg=""

	case "${notification_type}" in
		'taskgrp')
			msg="${c_bold}${notification_msg}${c_reset}"
			;;
		'task')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="  ${notification_msg}${c_reset}"
			fi
			;;
		'inf')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="${c_green}  * ${notification_msg}${c_reset}"
			fi
			;;
		'started')
			msg="${c_green} ${notification_msg}${c_reset}"
			;;
		'warn')
			msg="${c_brown}  * ${notification_msg}${c_reset}"
			;;
		'err')
			msg="${c_red}  * ${notification_msg}${c_reset}"
			;;
		'fatal')
			msg="${c_red}Error: ${notification_msg}${c_reset}"
			;;
		*)
			msg=""
			;;
	esac

	case "${notification_format}" in
		'n')
			options="-ne"
	  	;;
		*)
  		options="-e"
			;;
	esac

	[[ ! -z "${msg}" ]] && echo $options "${msg}"
}

function defunc() {
	notify 'fatal' "Please fix your configuration. Exiting..."
	exit 1
}

function display_startup_daemon() {
  $1 &>/dev/null
  res=$?
  if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
	  if [ $res = 0 ]; then
			notify 'started' " [ OK ]"
		else
	  	echo "false"
			notify 'err' " [ FAILED ]"
		fi
  fi
	return $res
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, except you know exactly what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<



##########################################################################
# >> Check Stack
#
# Description: Place functions for initial check of container sanity
##########################################################################
function check() {
	notify 'taskgrp' 'Checking configuration'
	for _func in "${FUNCS_CHECK[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _check_hostname() {
	notify "task" "Check that hostname/domainname is provided or overidden (no default docker hostname/kubernetes) [$FUNCNAME]"

	if [[ ! -z ${DEFAULT_VARS["OVERRIDE_HOSTNAME"]} ]]; then
		export HOSTNAME=${DEFAULT_VARS["OVERRIDE_HOSTNAME"]}
		export DOMAINNAME=$(echo $HOSTNAME | sed s/[^.]*.//)
	fi

	if ( ! echo $HOSTNAME | grep -E '^(\S+[.]\S+)$' > /dev/null ); then
		notify 'err' "Setting hostname/domainname is required"
		return 1
	else
		notify 'inf' "Domain has been set to $DOMAINNAME"
		notify 'inf' "Hostname has been set to $HOSTNAME"
		return 0
	fi
}

function _check_environment_variables() {
	notify "task" "Check that there are no conflicts with env variables [$FUNCNAME]"
	return 0
}
##########################################################################
# << Check Stack
##########################################################################


##########################################################################
# >> Setup Stack
#
# Description: Place functions for functional configurations here
##########################################################################
function setup() {
	notify 'taskgrp' 'Configuring mail server'
	for _func in "${FUNCS_SETUP[@]}";do
		$_func
	done
}

function _setup_default_vars() {
	notify 'task' "Setting up default variables [$FUNCNAME]"

	for var in ${!DEFAULT_VARS[@]}; do
		echo "export $var=${DEFAULT_VARS[$var]}" >> /root/.bashrc
		[ $? != 0 ] && notify 'err' "Unable to set $var=${DEFAULT_VARS[$var]}" && return 1
		notify 'inf' "Set $var=${DEFAULT_VARS[$var]}"
	done
}

function _setup_mailname() {
	notify 'task' 'Setting up Mailname'

	notify 'inf' "Creating /etc/mailname"
	echo $DOMAINNAME > /etc/mailname
}

function _setup_postfix_hostname() {
	notify 'task' 'Applying hostname and domainname to Postfix'

	notify 'inf' "Applying hostname to /etc/postfix/main.cf"
	postconf -e "myhostname = $HOSTNAME"
	postconf -e "mydomain = $DOMAINNAME"
}

function _setup_dovecot_hostname() {
	notify 'task' 'Applying hostname to Dovecot'

	notify 'inf' "Applying hostname to /etc/dovecot/conf.d/15-lda.conf"
	sed -i 's/^#hostname =.*$/hostname = '$HOSTNAME'/g' /etc/dovecot/conf.d/15-lda.conf
}

function _setup_dovecot() {
	notify 'task' 'Setting up Dovecot'

	cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
	sed -i -e 's/#ssl = yes/ssl = yes/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 993/port = 993/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 995/port = 995/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#ssl = yes/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf

	# Enable Managesieve service by setting the symlink
	# to the configuration file Dovecot will actually find
	if [ "$ENABLE_MANAGESIEVE" = 1 ]; then
		notify 'inf' "Sieve management enabled"
		mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
	fi

  notify 'inf' 'Compiling sieve scripts'
  /usr/bin/sievec /etc/dovecot/sieve
  /usr/bin/sievec /etc/dovecot/sieve/before.d

	# Copy pipe and filter programs, if any
	rm -f /usr/lib/dovecot/sieve-filter/*
	rm -f /usr/lib/dovecot/sieve-pipe/*
	if [ -d /tmp/docker-mailstack/sieve-filter ]; then
		cp /tmp/docker-mailstack/sieve-filter/* /usr/lib/dovecot/sieve-filter/
		chown docker:docker /usr/lib/dovecot/sieve-filter/*
		chmod 550 /usr/lib/dovecot/sieve-filter/*
	fi
	if [ -d /tmp/docker-mailstack/sieve-pipe ]; then
		cp /tmp/docker-mailstack/sieve-pipe/* /usr/lib/dovecot/sieve-pipe/
		chown docker:docker /usr/lib/dovecot/sieve-pipe/*
		chmod 550 /usr/lib/dovecot/sieve-pipe/*
	fi
}

function _setup_dovecot_local_user() {
	notify 'task' 'Setting up Dovecot Local User'
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailstack/postfix-accounts.cf ]; then
		notify 'inf' "Checking file line endings"
		sed -i 's/\r//g' /tmp/docker-mailstack/postfix-accounts.cf
		notify 'inf' "Regenerating postfix user list"
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

		# Checking that /tmp/docker-mailstack/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailstack/postfix-accounts.cf

		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb

		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
		grep -v "^\s*$\|^\s*\#" /tmp/docker-mailstack/postfix-accounts.cf | while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			notify 'inf' "user '${user}' for domain '${domain}' with password '********'"
			echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
			# User database for dovecot has the following format:
			# user:password:uid:gid:(gecos):home:(shell):extra_fields
			# Example :
			# ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
			echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
			mkdir -p /var/mail/${domain}
			if [ ! -d "/var/mail/${domain}/${user}" ]; then
				maildirmake.dovecot "/var/mail/${domain}/${user}"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
				echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
				touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
			fi
			# Copy user provided sieve file, if present
			test -e /tmp/docker-mailstack/${login}.dovecot.sieve && cp /tmp/docker-mailstack/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp
		done
	else
		notify 'inf' "'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
	fi
	postmap /etc/postfix/vmailbox
}

function _setup_postfix_sasl() {
    if [[ ${ENABLE_SASLAUTHD} == 1 ]];then
	[ ! -f /etc/postfix/sasl/smtpd.conf ] && cat > /etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
    fi

    # cyrus sasl or dovecot sasl
    if [[ ${ENABLE_SASLAUTHD} == 1 ]] || [[ ${SMTP_ONLY} == 0 ]];then
	sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = yes|g' /etc/postfix/main.cf
    else
	sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = no|g' /etc/postfix/main.cf
    fi

    return 0
}

function _setup_saslauthd() {
	notify 'task' "Setting up Saslauthd"

	notify 'inf' "Configuring Cyrus SASL"
	# checking env vars and setting defaults
	[ -z "$SASLAUTHD_MECHANISMS" ] && SASLAUTHD_MECHANISMS=pam

	if [ ! -f /etc/saslauthd.conf ]; then
		notify 'inf' "Creating /etc/saslauthd.conf"
		cat > /etc/saslauthd.conf << EOF
log_level: 10
EOF
	fi

		 sed -i \
		 -e "/^[^#].*smtpd_sasl_type.*/s/^/#/g" \
		 -e "/^[^#].*smtpd_sasl_path.*/s/^/#/g" \
		 /etc/postfix/master.cf

	sed -i \
		-e "s|^START=.*|START=yes|g" \
		-e "s|^MECHANISMS=.*|MECHANISMS="\"$SASLAUTHD_MECHANISMS\""|g" \
		-e "s|^MECH_OPTIONS=.*|MECH_OPTIONS="\"$SASLAUTHD_MECH_OPTIONS\""|g" \
		/etc/default/saslauthd

	if [ "$SASLAUTHD_MECHANISMS" = rimap ]; then
		sed -i \
			-e 's|^OPTIONS="|OPTIONS="-r |g' \
			/etc/default/saslauthd
	fi

	sed -i \
		-e "/smtpd_sasl_path =.*/d" \
		-e "/smtpd_sasl_type =.*/d" \
		-e "/dovecot_destination_recipient_limit =.*/d" \
		/etc/postfix/main.cf
	gpasswd -a postfix sasl
}

function _setup_postfix_aliases() {
	notify 'task' 'Setting up Postfix Aliases'

	echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailstack/postfix-virtual.cf ]; then
		# Copying virtual file
		cp -f /tmp/docker-mailstack/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1     other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailstack/postfix-virtual.cf
		postmap /etc/postfix/virtual

	else
		notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
	fi
	if [ -f /tmp/docker-mailstack/postfix-regexp.cf ]; then
		# Copying regexp alias file
		notify 'inf' "Adding regexp alias file postfix-regexp.cf"
		cp -f /tmp/docker-mailstack/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ regexp:.*//
		s/$/ regexp:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
		postmap /etc/postfix/regexp
	fi
}

function _setup_ssl() {
	notify 'task' "Setting up SSL [$SSL_TYPE for $HOSTNAME]"

	# SSL Configuration
	case $SSL_TYPE in
		"letsencrypt" )
			# letsencrypt folders and files mounted in /etc/letsencrypt
			if [ -e "/etc/letsencrypt/live/$HOSTNAME/cert.pem" ] \
			&& [ -e "/etc/letsencrypt/live/$HOSTNAME/fullchain.pem" ]; then
				KEY=""
				if [ -e "/etc/letsencrypt/live/$HOSTNAME/privkey.pem" ]; then
					KEY="privkey"
				elif [ -e "/etc/letsencrypt/live/$HOSTNAME/key.pem" ]; then
					KEY="key"
				fi
				if [ -n "$KEY" ]; then
					notify 'inf' "Adding $HOSTNAME SSL certificate"

					# Postfix configuration
					sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/letsencrypt/live/'$HOSTNAME'/fullchain.pem~g' /etc/postfix/main.cf
					sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/letsencrypt/live/'$HOSTNAME'/'"$KEY"'\.pem~g' /etc/postfix/main.cf

					# Dovecot configuration
					sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/letsencrypt/live/'$HOSTNAME'/fullchain\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
					sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/letsencrypt/live/'$HOSTNAME'/'"$KEY"'\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

					notify 'inf' "SSL configured with 'letsencrypt' certificates"
				fi
			fi
		;;
	"custom" )
		# Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
		if [ -e "/tmp/docker-mailstack/ssl/$HOSTNAME-full.pem" ]; then
			notify 'inf' "Adding $HOSTNAME SSL certificate"
			mkdir -p /etc/postfix/ssl
			cp "/tmp/docker-mailstack/ssl/$HOSTNAME-full.pem" /etc/postfix/ssl

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$HOSTNAME'-full.pem~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$HOSTNAME'-full.pem~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$HOSTNAME'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/'$HOSTNAME'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'CA signed/custom' certificates"
		fi
		;;
	"manual" )
		# Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole processes (like using kube-lego to generate certs)
		if [ -n "$SSL_CERT_PATH" ] \
		&& [ -n "$SSL_KEY_PATH" ]; then
			notify 'inf' "Configuring certificates using cert $SSL_CERT_PATH and key $SSL_KEY_PATH"
			mkdir -p /etc/postfix/ssl
			cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert
			cp "$SSL_KEY_PATH" /etc/postfix/ssl/key
			chmod 600 /etc/postfix/ssl/cert
			chmod 600 /etc/postfix/ssl/key

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/cert~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/key~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/cert~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/key~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'Manual' certificates"
		fi
	;;
	"self-signed" )
		# Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
		if [ -e "/tmp/docker-mailstack/ssl/$HOSTNAME-cert.pem" ] \
		&& [ -e "/tmp/docker-mailstack/ssl/$HOSTNAME-key.pem"  ] \
		&& [ -e "/tmp/docker-mailstack/ssl/$HOSTNAME-combined.pem" ] \
		&& [ -e "/tmp/docker-mailstack/ssl/demoCA/cacert.pem" ]; then
			notify 'inf' "Adding $HOSTNAME SSL certificate"
			mkdir -p /etc/postfix/ssl
			cp "/tmp/docker-mailstack/ssl/$HOSTNAME-cert.pem" /etc/postfix/ssl
			cp "/tmp/docker-mailstack/ssl/$HOSTNAME-key.pem" /etc/postfix/ssl
			# Force permission on key file
			chmod 600 /etc/postfix/ssl/$HOSTNAME-key.pem
			cp "/tmp/docker-mailstack/ssl/$HOSTNAME-combined.pem" /etc/postfix/ssl
			cp /tmp/docker-mailstack/ssl/demoCA/cacert.pem /etc/postfix/ssl

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$HOSTNAME'-cert.pem~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$HOSTNAME'-key.pem~g' /etc/postfix/main.cf
			sed -i -r 's~#smtpd_tls_CAfile=~smtpd_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
			sed -i -r 's~#smtp_tls_CAfile=~smtp_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
			ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$HOSTNAME.pem"

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$HOSTNAME'-combined\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/'$HOSTNAME'-key\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'self-signed' certificates"
		fi
		;;
	esac
}

function _setup_postfix_vhost() {
	notify 'task' "Setting up Postfix vhost"

	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
}

function _setup_docker_permit() {
	notify 'task' 'Setting up PERMIT_DOCKER Option'

	container_ip=$(ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
	container_network="$(echo $container_ip | cut -d '.' -f1-2).0.0"

	case $PERMIT_DOCKER in
		"host" )
			notify 'inf' "Adding $container_network/16 to my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_network/16"
			;;

		"network" )
			notify 'inf' "Adding docker network in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
			;;

		* )
			notify 'inf' "Adding container ip in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_ip/32"
			;;
	esac
}

function _setup_postfix_virtual_transport() {
	notify 'task' 'Setting up Postfix virtual transport'

	[ -z "${POSTFIX_DAGENT}" ] && \
		echo "${POSTFIX_DAGENT} not set." && \
		return 1
	postconf -e "virtual_transport = ${POSTFIX_DAGENT}"
}

function _setup_postfix_override_configuration() {
	notify 'task' 'Setting up Postfix Override configuration'

	if [ -f /tmp/docker-mailstack/postfix-main.cf ]; then
		while read line; do
		# all valid postfix options start with a lower case letter
		# http://www.postfix.org/postconf.5.html
		if [[ "$line" =~ ^[a-z] ]]; then
			postconf -e "$line"
		fi
		done < /tmp/docker-mailstack/postfix-main.cf
		notify 'inf' "Loaded 'config/postfix-main.cf'"
	else
		notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailstack/postfix-main.cf' not provided."
	fi
	if [ -f /tmp/docker-mailstack/postfix-master.cf ]; then
		while read line; do
		if [[ "$line" =~ ^[a-z] ]]; then
			postconf -P "$line"
		fi
		done < /tmp/docker-mailstack/postfix-master.cf
		notify 'inf' "Loaded 'config/postfix-master.cf'"
	else
		notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailstack/postfix-master.cf' not provided."
	fi
}

function _setup_postfix_sasl_password() {
	notify 'task' 'Setting up Postfix SASL Password'

	# Support general SASL password
	rm -f /etc/postfix/sasl_passwd
	if [ ! -z "$SASL_PASSWD" ]; then
		echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
	fi

	# Install SASL passwords
	if [ -f /etc/postfix/sasl_passwd ]; then
		chown root:root /etc/postfix/sasl_passwd
		chmod 0600 /etc/postfix/sasl_passwd
		notify 'inf' "Loaded SASL_PASSWD"
	else
		notify 'inf' "Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
	fi
}

function _setup_security_stack() {
	notify 'task' "Setting up Security Stack"

	# Fail2ban
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		notify 'inf' "Fail2ban enabled"
		test -e /tmp/docker-mailstack/fail2ban-jail.cf && cp /tmp/docker-mailstack/fail2ban-jail.cf /etc/fail2ban/jail.local
	else
		# Disable logrotate config for fail2ban if not enabled
		rm -f /etc/logrotate.d/fail2ban
	fi
}

function _setup_environment() {
    notify 'task' 'Setting up /etc/environment'

    local banner="# docker environment"
    local var
    if ! grep -q "$banner" /etc/environment; then
        echo $banner >> /etc/environment
    fi

    mkdir -p /var/mail-state/gpg-mailgate
    usermod -d /var/mail-state/gpg-mailgate nobody
}

function _setup_rspamd_passwd() {
    notify 'task', 'Setting up Rspamd password'
    HASH=`/usr/bin/rspamadm pw -p $RSPAMD_PASSWD`
    sed -i "s/q1/$HASH/g" /etc/rspamd/local.d/worker-controller.inc
}

function _setup_dkim() {
	notify 'task' 'Generating DKIM keypair if missing'
	mkdir -p /var/lib/rspamd/dkim
	while read -r domain; do
    KEY_FILE=/var/lib/rspamd/dkim/$domain.dkim.key
		if [ ! -f $KEY_FILE ]; then
			rspamadm dkim_keygen -b 2048 -d $domain -s 'mail' -k $KEY_FILE > /var/lib/rspamd/dkim/$domain.dkim.txt
			notify 'inf' "Private key for domain '$domain' is generated, here is DNS record:"
			cat /var/lib/rspamd/dkim/$domain.dkim.txt
		else
			notify 'inf' "Private key for domain '$DOMAINNAME' exists, nothing to do."
		fi 
	done < /etc/postfix/vhost
}

##########################################################################
# << Setup Stack
##########################################################################


##########################################################################
# >> Fix Stack
#
# Description: Place functions for temporary workarounds and fixes here
##########################################################################
function fix() {
	notify 'taskgrg' "Post-configuration checks..."
	for _func in "${FUNCS_FIX[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _fix_var_mail_permissions() {
	notify 'task' 'Checking /var/mail permissions'

	# Fix permissions, but skip this if 3 levels deep the user id is already set
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		notify 'inf' "Fixing /var/mail permissions"
		chown -R 5000:5000 /var/mail
	else
		notify 'inf' "Permissions in /var/mail look OK"
		return 0
	fi
}

function _fix_rspamd_permissions() {
	notify 'inf' "Fixing /etc/rspamd permissions"
	chown -R _rspamd /etc/rspamd
}

##########################################################################
# << Fix Stack
##########################################################################


##########################################################################
# >> Misc Stack
#
# Description: Place functions that do not fit in the sections above here
##########################################################################
function misc() {
	notify 'taskgrp' 'Starting Misc'

	for _func in "${FUNCS_MISC[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _misc_save_states() {
	# consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes
	statedir=/var/mail-state
	if [ "$ONE_DIR" = 1 -a -d $statedir ]; then
		notify 'inf' "Consolidating all state onto $statedir"
		for d in /var/spool/postfix /var/lib/postfix /var/lib/fail2ban /var/lib/rspamd /var/lib/redis; do
			dest=$statedir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
			if [ -d $dest ]; then
				notify 'inf' "  Destination $dest exists, linking $d to it"
				rm -rf $d
				ln -s $dest $d
			elif [ -d $d ]; then
				notify 'inf' "  Moving contents of $d to $dest:" `ls $d`
				mv $d $dest
				ln -s $dest $d
			else
				notify 'inf' "  Linking $d to $dest"
				mkdir -p $dest
				ln -s $dest $d
			fi
		done

		notify 'inf' 'Fixing /var/mail-state/* permissions'
		chown -R postfix /var/mail-state/lib-postfix
		chown -R postfix /var/mail-state/spool-postfix
		chown -R _rspamd /var/mail-state/lib-rspamd
		chown -R redis   /var/mail-state/lib-redis

	fi
}

##########################################################################
# >> Start Daemons
##########################################################################
function start_daemons() {
	notify 'taskgrp' 'Starting mail server'

	for _func in "${DAEMONS_START[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _start_daemons_cron() {
	notify 'task' 'Starting cron' 'n'
	display_startup_daemon "cron"
}

function _start_daemons_rsyslog() {
	notify 'task' 'Starting rsyslog' 'n'
	display_startup_daemon "/etc/init.d/rsyslog start"
}

function _start_daemons_saslauthd() {
	notify 'task' 'Starting saslauthd' 'n'
	display_startup_daemon "/etc/init.d/saslauthd start"
}

function _start_daemons_fail2ban() {
	notify 'task' 'Starting fail2ban' 'n'
	touch /var/log/auth.log
	# Delete fail2ban.sock that probably was left here after container restart
	if [ -e /var/run/fail2ban/fail2ban.sock ]; then
		rm /var/run/fail2ban/fail2ban.sock
	fi
	display_startup_daemon "/etc/init.d/fail2ban start"
}

function _start_daemons_postfix() {
	notify 'task' 'Starting postfix' 'n'
	display_startup_daemon "/etc/init.d/postfix start"
}

function _start_daemons_dovecot() {
	# Here we are starting sasl and imap, not pop3 because it's disabled by default
	notify 'task' 'Starting dovecot services' 'n'
	display_startup_daemon "/usr/sbin/dovecot -c /etc/dovecot/dovecot.conf"

	if [ "$ENABLE_POP3" = 1 ]; then
		notify 'task' 'Starting pop3 services' 'n'
		mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
		display_startup_daemon "/usr/sbin/dovecot reload"
	fi

	if [ -f /tmp/docker-mailstack/dovecot.cf ]; then
		cp /tmp/docker-mailstack/dovecot.cf /etc/dovecot/local.conf
		/usr/sbin/dovecot reload
	fi

	# @TODO fix: on integration test
	# doveadm: Error: userdb lookup: connect(/var/run/dovecot/auth-userdb) failed: No such file or directory
	# doveadm: Fatal: user listing failed
}

function _start_daemons_redis() {
	notify 'task' 'Starting redis' 'n'
	mkdir -p /var/lib/redis
	display_startup_daemon "redis-server /etc/redis/redis.conf"
}

function _start_daemons_rspamd() {
	notify 'task' 'Starting rspamd' 'n'
	display_startup_daemon "/etc/init.d/rspamd start"
}

##########################################################################
# << Start Daemons
##########################################################################





# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>

if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# ENV"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""
printenv
fi

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# docker-mailserver"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""

register_functions

check
setup
fix
misc
start_daemons

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "# $HOSTNAME is up and running"
notify 'taskgrp' "#"
notify 'taskgrp' ""


tail -fn 0 /var/log/mail/mail.log


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<

exit 0
