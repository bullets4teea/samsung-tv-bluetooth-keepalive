#!/bin/sh
# Sourced by a signed shell; Samsung UEP rejects unsigned shell-file arguments.
BASE=${BASE:-/opt/usr/share/tv-audio-keepalive}
STATE=${STATE:-/run/tv-audio-keepalive}
POLL_SECONDS=${POLL_SECONDS:-5}
TARGET_ADDRESS=$(cat "$BASE/headphone-address" 2>/dev/null | tr '[:lower:]' '[:upper:]')
case "$TARGET_ADDRESS" in
    [0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]) ;;
    *) echo 'Invalid or missing headphone-address' >&2; exit 1 ;;
esac
mkdir -p "$STATE" || exit 1
audio_pid=
last_status=
status() {
    if [ "$last_status" != "$1" ]; then
        printf '%s\n' "$1" > "$STATE/status"
        last_status=$1
    fi
}
stop_audio() {
    if [ -n "$audio_pid" ]; then
        kill "$audio_pid" 2>/dev/null
        wait "$audio_pid" 2>/dev/null
        audio_pid=
    fi
}
cleanup() { stop_audio; status stopped; }
trap cleanup EXIT
trap 'exit 0' INT TERM
while :; do
    if [ -f "$BASE/disabled" ]; then
        stop_audio
        status disabled
    else
        connected=$(gdbus call --timeout 5 --system \
            --dest com.samsung.tv.bt.connectionmanager \
            --object-path /com/samsung/tv/bt/connectionmanager \
            --method org.tizen.btapp.ApiInterface.get_connected_bt_speaker_info \
            2>/dev/null | tr '[:lower:]' '[:upper:]')
        case "$connected" in
            *"$TARGET_ADDRESS"*)
                if [ -z "$audio_pid" ] || ! kill -0 "$audio_pid" 2>/dev/null; then
                    wait "$audio_pid" 2>/dev/null
                    pacat --playback --raw --format=s16le --rate=48000 --channels=2 \
                        --client-name=TV-Audio-Keepalive --stream-name=TV-Audio-Keepalive \
                        --property=media.role=media </dev/zero >/dev/null 2>&1 &
                    audio_pid=$!
                    sleep 1
                fi
                if kill -0 "$audio_pid" 2>/dev/null; then
                    status active
                else
                    status waiting-for-audio
                fi
                ;;
            *) stop_audio; status waiting-for-headphones ;;
        esac
    fi
    sleep "$POLL_SECONDS"
done
