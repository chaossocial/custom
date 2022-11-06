#!/bin/bash
set -e

MAX_USERS=42
RAILS_ENV=production

# Config grabbing yoinked from https://codeberg.org/Windfluechter/check_mastodon.sh/src/branch/main/check_mastodon.sh
CONFIG="${HOME}/bin/registration_limit.conf"
if [ ! -e "${CONFIG}" ]; then
	grep -e ^"DB_" -e ^"LOCAL_DOMAIN" "${HOME}/live/.env.production" > "${CONFIG}"
fi
. "${CONFIG}"

mastodon_psql () {
	echo "$(/usr/bin/psql -U "${DB_USER}" -w -h "${DB_HOST}" -p "${DB_PORT}" -t "${DB_NAME}" -c "$1")"
}

INVITE_ROLE="$(mastodon_psql "SELECT value FROM settings WHERE var LIKE 'min_invite_role';")"
USERS_TODAY="$(mastodon_psql "SELECT count(*) FROM users WHERE users.created_at::date = NOW()::date AND disabled=false;")"
echo "$USERS_TODAY"

# TODO fix the redis-cli lines so that the special characters don't get escaped
# (To see what's happening, compare "get test:rixx" with "get cache:rails_settings_cached/8cf69c0340d0506f5783bd343106ebea/min_invite_role")

# TODO (not urgent) in both branches, use a method to get the correct redis key
# redis-cli -h localhost -p 6379 keys cache:rails_settings_cached/*/min_invite_role
# output: 1) "cache:rails_settings_cached/8cf69c0340d0506f5783bd343106ebea/min_invite_role"
# we need to cut out only the "1)"

if [ "$USERS_TODAY" -lt "$MAX_USERS" ] && [[ "$INVITE_ROLE" == *"admin"* ]]; then
	# Few sign-ups but admin mode, date rollover
	echo "opening registrations and restoring invites"
	mastodon_psql "UPDATE invites SET expires_at=TO_TIMESTAMP(comment, 'YYYY-MM-DD HH24:MI:SS.US'), comment='' WHERE expires_at='1999-09-09 00:00:00';"
	mastodon_psql "UPDATE settings SET value = REPLACE(value, 'admin', 'user'), updated_at=NOW() WHERE var = 'min_invite_role';"
	#redis-cli -h localhost -p 6379 set "cache:rails_settings_cached/8cf69c0340d0506f5783bd343106ebea/min_invite_role" "\x04\bo: ActiveSupport::Cache::Entry\t:\x0b@valueI\"\tuser\x06:\x06ET:\r@version0:\x10@created_atf\x171667700951.1239355:\x10@expires_inf\b6e2" PX 600000
elif [ "$USERS_TODAY" -gt $MAX_USERS ] && [[ "$INVITE_ROLE" == *"user"* ]] ; then
	# Too many sign-ups but still in user mode
	echo "closing registrations and disabling invites"
	mastodon_psql "UPDATE invites SET comment=expires_at, expires_at='1999-09-09 00:00:00' WHERE (max_uses IS NULL OR uses < max_uses) AND (expires_at IS NULL OR expires_at > now());"
	mastodon_psql "UPDATE settings SET value = REPLACE(value, 'user', 'admin'), updated_at=NOW() WHERE var = 'min_invite_role';"
	#redis-cli -h localhost -p 6379 set "cache:rails_settings_cached/8cf69c0340d0506f5783bd343106ebea/min_invite_role" "\x04\bo: ActiveSupport::Cache::Entry\t:\x0b@valueI\"\tadmin\x06:\x06ET:\r@version0:\x10@created_atf\x171667700951.1239355:\x10@expires_inf\b6e2" PX 600000
fi
