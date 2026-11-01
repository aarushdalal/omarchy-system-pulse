"""Exercise storage collection, process failures and rendering without the live shell.

Requires Qt Quick/QtTest and Quickshell. The isolated harness copies the current
implementation, uses synthetic collector responses and writes only to a temporary
folder. Its palette is a fixture, not a screenshot of the user's desktop.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StorageCollector(unittest.TestCase):
    def test_real_collector_emits_explicit_smart_availability(self):
        response = subprocess.run(['bash', str(ROOT / 'services/stats-collector.sh')],
                                  capture_output=True, text=True, timeout=10, check=True)
        sample = json.loads(response.stdout)
        self.assertEqual(sample['storage']['smart'], {'state': 'unavailable', 'reason': 'not-collected'})
        for section in ('cpu', 'gpu', 'ram', 'battery'):
            self.assertIsInstance(sample[section], dict)
        temperature = sample['storage']['nvme_temp']
        self.assertTrue(temperature is None or -40 <= temperature <= 150)

    def test_df_failure_missing_and_zero_values(self):
        collector = (ROOT / 'services/stats-collector.sh').read_text()
        function = collector[collector.index('capacity_json() {'):collector.index('\nroot_part=')]
        for output, status, expected in [
            ('', 1, None), ('Filesystem Size Used Avail Use% Mounted\n', 0, None),
            ('Filesystem Size Used Avail Use% Mounted\nroot 10G 0G 10G 0% /\n', 0,
             {'name': 'Root', 'total': 10, 'used': 0, 'free': 10, 'pct': 0}),
            ('Filesystem Size Used Avail Use% Mounted\nroot bad 1G 9G 10% /\n', 0, None),
        ]:
            # Fixture environment feeds a mock df function, never the shell program.
            program = 'df() { printf "%s" "$DF_OUTPUT"; return "$DF_STATUS"; }\n' + function + '\ncapacity_json / Root\n'
            env = dict(os.environ, DF_OUTPUT=output, DF_STATUS=str(status), LC_ALL='C')
            result = subprocess.run(['bash', '-euo', 'pipefail', '-c', program], env=env,
                                    capture_output=True, text=True, timeout=5, check=True)
            self.assertEqual(json.loads(result.stdout), expected)

    @unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is not installed')
    def test_process_error_recovery_and_storage_card(self):
        with tempfile.TemporaryDirectory(prefix='system-pulse-storage-test-') as name:
            folder = Path(name)
            shutil.copytree(ROOT / 'tests/storage_harness', folder, dirs_exist_ok=True)
            (folder / 'cards').mkdir()
            for file in ('HardwareStats.qml', 'StorageState.js'):
                shutil.copy2(ROOT / 'services' / file, folder / 'services' / file)
            shutil.copy2(ROOT / 'cards/StorageCard.qml', folder / 'cards/StorageCard.qml')
            # Deployed personalized builds also have a background polling toggle;
            # upstream uses active-only polling. Preserve and test each own API.
            if 'property bool backgroundPolling' not in (folder / 'services/HardwareStats.qml').read_text():
                path = folder / 'shell.qml'
                path.write_text(path.read_text().replace('; backgroundPolling: false', ''))
            (folder / 'services/fixture-mode').write_text('partial')
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CACHE_HOME=str(folder / 'cache'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '--no-color', '--path', str(folder)], env=env,
                                    capture_output=True, text=True, timeout=12)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn('STORAGE-PASS 13 integration checks', log)
            self.assertNotIn('STORAGE-FAIL', log)
            self.assertNotIn('ERROR', log)
            self.assertTrue((folder / 'partial-storage.png').is_file())


if __name__ == '__main__':
    unittest.main()
