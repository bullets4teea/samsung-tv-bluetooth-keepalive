"""Behavior tests with fake TV interfaces; no TV or root required."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

WORKER = Path(__file__).resolve().parents[1] / 'worker.sh'

class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        (self.bin / 'gdbus').write_text('#!/bin/sh\ncat "$BASE/connected"\n')
        (self.bin / 'pacat').write_text('''#!/bin/sh
if [ -f "$BASE/fail-audio" ]; then exit 1; fi
echo $$ >> "$BASE/starts"
trap 'echo stopped >> "$BASE/stops"; exit 0' TERM INT
while :; do sleep 0.1; done
''')
        for f in self.bin.iterdir():
            f.chmod(0o700)
        (self.base / 'headphone-address').write_text('AA:BB:CC:DD:EE:FF\n')
        (self.base / 'connected').write_text('[]')
        self.env = dict(os.environ, BASE=str(self.base), STATE=str(self.base / 'state'),
                        POLL_SECONDS='0.1', PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.proc = None

    def tearDown(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        self.tmp.cleanup()

    def start(self):
        self.proc = subprocess.Popen(['/bin/sh', str(WORKER)], env=self.env,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def status(self):
        try:
            return (self.base / 'state/status').read_text().strip()
        except FileNotFoundError:
            return None

    def wait(self, predicate):
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.05)
        self.fail('Worker did not reach expected state: ' + str(self.status()))

    def test_only_selected_headset_and_cleanup(self):
        self.start()
        self.wait(lambda: self.status() == 'waiting-for-headphones')
        (self.base / 'connected').write_text('11:22:33:44:55:66')
        time.sleep(.2)
        self.assertFalse((self.base / 'starts').exists())
        (self.base / 'connected').write_text('aa:bb:cc:dd:ee:ff')
        self.wait(lambda: self.status() == 'active')
        time.sleep(.3)
        self.assertEqual(len((self.base / 'starts').read_text().splitlines()), 1)
        (self.base / 'connected').write_text('[]')
        self.wait(lambda: self.status() == 'waiting-for-headphones')
        self.assertEqual((self.base / 'stops').read_text().count('stopped'), 1)
        (self.base / 'connected').write_text('AA:BB:CC:DD:EE:FF')
        self.wait(lambda: self.status() == 'active')
        (self.base / 'disabled').touch()
        self.wait(lambda: self.status() == 'disabled')
        self.assertEqual((self.base / 'stops').read_text().count('stopped'), 2)

    def test_failed_audio_recovers_and_signal_cleans_up(self):
        (self.base / 'connected').write_text('AA:BB:CC:DD:EE:FF')
        (self.base / 'fail-audio').touch()
        self.start()
        self.wait(lambda: self.status() == 'waiting-for-audio')
        (self.base / 'fail-audio').unlink()
        self.wait(lambda: self.status() == 'active')
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.assertEqual(self.status(), 'stopped')
        self.assertEqual((self.base / 'stops').read_text().count('stopped'), 1)

    def test_invalid_configuration_fails_closed(self):
        (self.base / 'headphone-address').write_text('invalid')
        self.start()
        self.assertEqual(self.proc.wait(timeout=3), 1)
        self.assertFalse((self.base / 'starts').exists())

if __name__ == '__main__':
    unittest.main()
