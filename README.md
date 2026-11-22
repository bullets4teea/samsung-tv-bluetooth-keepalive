# This have been done with AI but human check and read. 

# this fix was only because it hate how it would randomly disconnect from my headset.  have fun


# Samsung TV Bluetooth audio keepalive

A TV-local workaround for Bluetooth audio becoming silent or distorted after
YouTube advertisements, seeking, or playback transitions. It plays **digital
silence** continuously while one configured Bluetooth headset is connected.
The silent PCM stream keeps the audio path active. No computer, server, Internet
connection or periodic remote command is needed after installation.

**Partial improvement, not a complete fix.** On 22 November 2026, the owner
reported that switching apps worked normally and was substantially better with
this TV-local workaround. They chose to keep it installed and share it.
However, switching YouTube videos had also reproduced silence and distortion
while the native service and silent stream were running and the headset was
connected. Ads and seeking are not reliably fixed. Reconnecting the headset
restored clear sound during testing, but this package does not automate
reconnections. The root cause remains unresolved. It does not remove ads.

The **startup is persistent** and was verified after a full TV restart. That
does not mean the underlying Bluetooth fault is permanently fixed. No PC-side
controller is included or required for normal operation.

## Tested configuration

- Samsung QE65QN90BATXXU (QN90B), Tizen 6.5, ARMv7.
- Firmware T-PTMDEUC-1720.7, build 20260225.1.
- AirPods Pro; the owner's Bluetooth address is not included.
- TV-native systemd service starts successfully and produces one silent stream.
- Vendor AT-HUB startup hook tested successfully, with its original action retained.
- **Full restart verified on 22 November 2026:** the kernel boot ID changed,
  AT-HUB completed successfully, and the audio service started automatically
  while the previous host controller was disabled. It waited for the headset
  to connect, then automatically became active with one silent stream and no
  service restarts. The owner then confirmed the headset connected and audio
  was working normally after the restart. Extended playback testing remains
  useful; this is not a guarantee for every app or transition.

The reported improvement in app switching is an owner observation, not a
controlled compatibility test. Jellyfin episode changes, Netflix playback,
YouTube ads and repeated seeks still need further validation. The later
ten-minute comparison trial was cancelled; it is not evidence of a fix and
is not part of this package.

## What changes

The package installs under `/opt/usr/share/tv-audio-keepalive/` and backs up the
exact stock `/opt/etc/parseinfo.sh` before changing it. The replacement hook
runs the original signed script, then creates a runtime systemd service. The
service runs as the existing `sdk` user with audio-group access, rather than
running the audio loop as root. It checks for the configured headset every
five seconds and stops its stream when that headset disconnects.

The stock `starter.target` already starts `AT-HUB.service` on this tested TV.
The persistent hook recreates `/run/systemd/system/tv-audio-keepalive.service`
after a reboot; no persistent root connection or rootfs modification is used.
A local `disabled` file provides an off switch. Picture, colour, volume,
headphone pairing and audio-format preferences are not changed.

The installer accepts only the reviewed stock hook SHA-256:

```
c6369e7dec69408e176daa252d436acf6f8e265f560504d8bd831c8023c71d61
```

It refuses an unknown hook instead of overwriting another modification. Do not
remove that check to force installation on an untested TV. Firmware updates or
resets may replace the hook; this has not been tested.

## Requirements

1. A compatible TV with an already verified, temporary root method. This package
   does not obtain root itself.
2. A backup of the original startup script and a working way to restore it.
3. Samsung's signed `gawk`, `bash`, `pacat` and `gdbus` binaries; the expected
   AT-HUB startup symlink and a working systemd manager.
4. For the optional uploader, Python and the source installation of
   [samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root), plus SDB
   and Developer Mode configured according to that project's documentation.
   The computer is needed only to install, inspect or remove the package.

Do not upload TV backups, logs, certificates or real headset addresses to your
public repository. The package contains no Samsung firmware or vendor script.

## Install

Read the six files listed in `SHA256SUMS` first. Back up your TV before changing
its startup behaviour. If another host-managed keepalive is running, disable
it before the final activation so there is only one silent stream.

Set your TV's local address, then upload the package using the Python environment
where `samsung-tv-root` is installed:

```sh
TV=192.0.2.50  # replace with your TV's local IP
python upload.py --host "$TV" --headphones AA:BB:CC:DD:EE:FF
```

Replace the example Bluetooth address with your headset address. If necessary,
pass `--sdb /path/to/sdb`, `--callback-host YOUR_COMPUTER_IP` and
`--callback-port PORT`; allow that callback from your TV through your firewall.
The uploader stages files only. It does not install or start the workaround.

From your established root session, run:

```sh
STAGE=/home/owner/share/tmp/sdk_tools/tv-audio-native-install \
MODE=install /bin/bash -c '. /home/owner/share/tmp/sdk_tools/tv-audio-native-install/install.sh'
systemctl start AT-HUB.service
systemctl show AT-HUB.service -p Result -p ExecMainStatus
systemctl show tv-audio-keepalive.service -p ActiveState -p MainPID
cat /run/tv-audio-keepalive/status
```

If using the upstream command-line tool, each command can be passed to
`samsung-tv-root archive-root root "$TV" --command 'COMMAND'`. Follow its
root acquisition and callback-network instructions. Root access is needed for
installation and rollback; ordinary SDB shell access is not sufficient.

Samsung UEP rejects unsigned shell files passed directly as interpreter
arguments. The scripts are intentionally **sourced** using the signed shell;
the startup hook uses the signed `gawk` interpreter. Do not replace the commands
above with `sh install.sh`.

### Verify without a computer

1. Verify `AT-HUB.service` reports success. Connect the configured headset;
   `/run/tv-audio-keepalive/status` should become `active`.
2. Disable any previous computer-side controller.
3. Record `/proc/sys/kernel/random/boot_id`, fully power-cycle the TV, then
   check that the boot ID changed and the service started without a manual start.
4. With the computer off, test a YouTube advertisement, a seek and a new episode.
5. Disconnect the headset; the stream should stop. Other headsets should not
   activate it unless you explicitly change the configuration.

The root tool may be needed again to inspect or roll back; reconnecting it
for inspection must not be mistaken for the workaround starting automatically.

## Disable or remove

From a root session, stop it now and prevent it starting next boot:

```sh
touch /opt/usr/share/tv-audio-keepalive/disabled
systemctl stop tv-audio-keepalive.service
```

To re-enable:

```sh
rm -f /opt/usr/share/tv-audio-keepalive/disabled
/bin/bash -c '. /opt/usr/share/tv-audio-keepalive/boot.sh'
```

To restore the exact original startup script and remove the runtime service:

```sh
/bin/bash -c '. /opt/usr/share/tv-audio-keepalive/uninstall.sh'
```

The uninstaller checks the backup and current hook hashes before restoring.
It leaves the inactive package and backup in place. Keep your off-TV backup
until a full restart confirms normal behaviour.

## Tests and provenance

Run local behavioural tests without a TV:

```sh
python -m unittest discover -s tests -v
```

They cover headset selection, disconnect/reconnect, the disabled switch, audio
process failure/recovery, shutdown cleanup and invalid configuration.

The AT-HUB/gawk startup approach was documented in
[levkropp's at-hub-persistence module](https://github.com/levkropp/samsung-tv-root-untethered/tree/master/modules/at-hub-persistence).
This package implements a separate audio-only service and calls the preserved
vendor script; it does not install that project's root agent or other modules.
The silent stream uses the standard
[PulseAudio pacat utility](https://github.com/pulseaudio/pulseaudio/blob/master/src/utils/pacat.c).
