#!/usr/bin/gawk -f
# Keep the signed vendor script intact and run it before our optional service.
# gawk reads data without asking bash to execute an unsigned script file.
BEGIN {
    original = system("/bin/bash /opt/usr/share/tv-audio-keepalive/parseinfo.sh.stock")
    system("/bin/bash -c '. /opt/usr/share/tv-audio-keepalive/boot.sh' >/dev/null 2>&1")
    # AT-HUB passes '&' as an argument. Do not treat it as an input filename.
    exit original
}
