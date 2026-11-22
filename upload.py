#!/usr/bin/env python3
"""Upload reviewed files; installation is a separate, explicit root command."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import re
import tempfile
from samsung_tv_root.sdb import SdbClient, find_sdb

STAGE = '/home/owner/share/tmp/sdk_tools/tv-audio-native-install'
FILES = ('worker.sh', 'boot.sh', 'hook.awk', 'tv-audio-keepalive.service',
         'install.sh', 'uninstall.sh')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True, help='TV local IP address')
    parser.add_argument('--headphones', required=True, help='Bluetooth address AA:BB:CC:DD:EE:FF')
    parser.add_argument('--sdb', type=Path)
    parser.add_argument('--callback-host', help='This computer address reachable from TV')
    parser.add_argument('--callback-port', type=int, default=0)
    args = parser.parse_args()
    if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', args.headphones):
        parser.error('Invalid Bluetooth address')
    source = Path(__file__).resolve().parent
    expected = dict(line.split(maxsplit=1)[::-1]
                    for line in (source / 'SHA256SUMS').read_text().splitlines())
    for name in FILES:
        digest = hashlib.sha256((source / name).read_bytes()).hexdigest()
        if digest != expected.get(name):
            raise SystemExit('Checksum mismatch: ' + name)
    client = SdbClient(args.sdb or find_sdb(), args.host)
    client.connect()
    client.require_device()
    result = client.capture('mkdir -p ' + STAGE, callback_host=args.callback_host,
                            port=args.callback_port)
    if '[exit:0]' not in result.output:
        raise SystemExit('Could not create upload directory')
    for name in (*FILES, 'SHA256SUMS'):
        client.push(source / name, PurePosixPath(STAGE + '/' + name))
    with tempfile.TemporaryDirectory() as temporary:
        configuration = Path(temporary) / 'headphone-address'
        configuration.write_text(args.headphones.upper() + '\n')
        client.push(configuration, PurePosixPath(STAGE + '/headphone-address'))
    print('Uploaded. Nothing has been installed or enabled yet.')
    print('Follow README.md to install from a root session and verify a full restart.')


if __name__ == '__main__':
    main()
