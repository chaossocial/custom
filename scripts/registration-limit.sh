#!/bin/bash
set -e

MAX_USERS=23
RAILS_ENV=production

# Config grabbing yoinked from https://codeberg.org/Windfluechter/check_mastodon.sh/src/branch/main/check_mastodon.sh
CONFIG="${HOME}/bin/registration_limit.conf"
if [ ! -e "${CONFIG}" ]; then
	grep -e ^"DB_" -e ^"LOCAL_DOMAIN" "${HOME}/live/.env.production" > "${CONFIG}"
fi
. "${CONFIG}"
export PGPASSWORD="$DB_PASS"

mastodon_psql () {
	echo "$(/usr/bin/psql -U "${DB_USER}" -w -h "${DB_HOST}" -p "${DB_PORT}" -t "${DB_NAME}" -c "$1")"
}

INVITE_ROLE="$(mastodon_psql "SELECT get_bit(permissions::bit(32), 15) from user_roles where name='';")"
USERS_TODAY="$(mastodon_psql "SELECT count(*) FROM users WHERE TIMEZONE('UTC', users.created_at)::date = NOW()::date AND disabled=false;")"
echo "$USERS_TODAY"

if [ "$USERS_TODAY" -lt "$MAX_USERS" ] && [[ "$INVITE_ROLE" == *"0"* ]]; then
	# Few sign-ups but admin mode, date rollover
	echo "opening registrations and restoring invites"
	mastodon_psql "UPDATE invites SET expires_at=TO_TIMESTAMP(comment, 'YYYY-MM-DD HH24:MI:SS.US'), comment='' WHERE expires_at='1999-09-09 00:00:00';"
	mastodon_psql "UPDATE user_roles SET permissions = set_bit(permissions::bit(32), 15, 1)::int WHERE name='';"
	REDISKEY="$(redis-cli --raw keys cache:rails_settings_cached/*/min_invite_role)"
	redis-cli del "$REDISKEY"
elif [ "$USERS_TODAY" -ge $MAX_USERS ] && [[ "$INVITE_ROLE" == *"1"* ]] ; then
	# Too many sign-ups but still in user mode
	echo "closing registrations and disabling invites"
	mastodon_psql "UPDATE invites SET comment=expires_at, expires_at='1999-09-09 00:00:00' WHERE (max_uses IS NULL OR uses < max_uses) AND (expires_at IS NULL OR expires_at > now());"
	mastodon_psql "UPDATE user_roles SET permissions = set_bit(permissions::bit(32), 15, 0)::int WHERE name='';"
	REDISKEY="$(redis-cli --raw keys cache:rails_settings_cached/*/min_invite_role)"
	redis-cli del "$REDISKEY"
fi
