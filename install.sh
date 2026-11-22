#!/bin/sh
# Run in an existing root session, sourced or via stdin (Samsung UEP).
set -eu
BASE=/opt/usr/share/tv-audio-keepalive
HOOK=/opt/etc/parseinfo.sh
STOCK_SHA=c6369e7dec69408e176daa252d436acf6f8e265f560504d8bd831c8023c71d61
STAGE=${STAGE:?Set STAGE to the uploaded package directory}
MODE=${MODE:-install}
[ "$(id -u)" = 0 ] || { echo 'Root is required'; exit 1; }
case "$MODE" in stage|install) ;; *) echo 'MODE must be stage or install'; exit 1;; esac
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
current=$(sha "$HOOK")
new=$(sha "$STAGE/hook.awk")
if [ "$current" != "$STOCK_SHA" ] && [ "$current" != "$new" ]; then
    echo 'Refusing to overwrite an unknown or previously modified startup hook.'
    exit 1
fi
[ -x /usr/bin/gawk ] && [ -x /usr/bin/pacat ] && [ -x /usr/bin/gdbus ]
[ -L /usr/lib/systemd/system/starter.target.wants/AT-HUB.service ]
[ -f "$STAGE/headphone-address" ]
grep -Eq '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$' "$STAGE/headphone-address"
[ "$(wc -l < "$STAGE/headphone-address")" -eq 1 ]
# Verify all public source bytes before changing the persistent installation.
(cd "$STAGE" && sha256sum -c SHA256SUMS)
mkdir -p "$BASE"
if [ ! -f "$BASE/parseinfo.sh.stock" ]; then
    [ "$current" = "$STOCK_SHA" ]
    cp -p "$HOOK" "$BASE/parseinfo.sh.stock"
    chmod 600 "$BASE/parseinfo.sh.stock"
fi
[ "$(sha "$BASE/parseinfo.sh.stock")" = "$STOCK_SHA" ]
for name in worker.sh boot.sh tv-audio-keepalive.service hook.awk uninstall.sh; do
    cp "$STAGE/$name" "$BASE/$name.new"
    chmod 644 "$BASE/$name.new"
    chown 0:0 "$BASE/$name.new"
    mv "$BASE/$name.new" "$BASE/$name"
done
cp "$STAGE/headphone-address" "$BASE/headphone-address"
chown 0:0 "$BASE" "$BASE/headphone-address" "$BASE/parseinfo.sh.stock"
chmod 755 "$BASE"
chmod 644 "$BASE/headphone-address"
if command -v chsmack >/dev/null 2>&1; then
    chsmack -a System "$BASE" "$BASE/worker.sh" "$BASE/boot.sh" \
        "$BASE/tv-audio-keepalive.service" "$BASE/headphone-address"
fi
if [ "$MODE" = stage ]; then
    echo 'Staged and backed up; vendor startup hook has not been changed.'
    exit 0
fi
# Preserve the existing inode and its firmware security labels.
if ! cat "$BASE/hook.awk" > "$HOOK" || [ "$(sha "$HOOK")" != "$new" ]; then
    cat "$BASE/parseinfo.sh.stock" > "$HOOK"
    chmod 777 "$HOOK"
    echo 'Hook verification failed; restored original.'
    exit 1
fi
chmod 755 "$HOOK"
chown 0:0 "$HOOK"
sync
echo 'Installed. Start AT-HUB.service to test, then verify a cold boot.'
