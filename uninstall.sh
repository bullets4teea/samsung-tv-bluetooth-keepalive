#!/bin/sh
set -eu
BASE=/opt/usr/share/tv-audio-keepalive
HOOK=/opt/etc/parseinfo.sh
STOCK_SHA=c6369e7dec69408e176daa252d436acf6f8e265f560504d8bd831c8023c71d61
[ "$(id -u)" = 0 ] || { echo 'Root is required'; exit 1; }
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
[ "$(sha "$BASE/parseinfo.sh.stock")" = "$STOCK_SHA" ]
current=$(sha "$HOOK")
[ "$current" = "$STOCK_SHA" ] || [ "$current" = "$(sha "$BASE/hook.awk")" ] || {
    echo 'Startup hook has changed since installation; refusing to overwrite it.'; exit 1;
}
touch "$BASE/disabled"
systemctl stop tv-audio-keepalive.service || true
cat "$BASE/parseinfo.sh.stock" > "$HOOK"
chmod 777 "$HOOK"
chown 0:0 "$HOOK"
[ "$(sha "$HOOK")" = "$STOCK_SHA" ]
rm -f /run/systemd/system/tv-audio-keepalive.service
systemctl daemon-reload
sync
echo 'Original startup hook restored. Backup and inactive package retained.'
