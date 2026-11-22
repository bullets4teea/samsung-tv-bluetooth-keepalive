#!/bin/sh
BASE=/opt/usr/share/tv-audio-keepalive
# AT-HUB is already starting under systemd. Never wait for another boot job.
if [ ! -f "$BASE/disabled" ]; then
    cp "$BASE/tv-audio-keepalive.service" /run/systemd/system/tv-audio-keepalive.service &&
        systemctl daemon-reload &&
        systemctl --no-block start tv-audio-keepalive.service
fi
