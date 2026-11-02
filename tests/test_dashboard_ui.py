"""Actual dashboard UI in an isolated renderer, without desktop input or services.

The fixture copies current dashboard/tabs/material/motion code. It replaces only
native popup anchoring/focus, live data and unrelated cards. Rendering is real Qt
Quick; this is not evidence about a user's compositor or sustained frame rate.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DashboardUI(unittest.TestCase):
    @unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is not installed')
    def test_actual_controls_transitions_and_layout(self):
        with tempfile.TemporaryDirectory(prefix='system-pulse-dashboard-ui-') as name:
            folder = Path(name)
            subprocess.run([sys.executable, str(ROOT / 'tests/build_dashboard_fixture.py'),
                            str(ROOT), str(folder)], check=True, capture_output=True, text=True, timeout=5)
            content = (ROOT / 'tests/dashboard_ui_fixture/shell.qml').read_text()
            entry = ROOT / ('SystemPlusDashboard.qml' if (ROOT / 'SystemPlusDashboard.qml').exists()
                            else 'SystemPulseDashboard.qml')
            if 'property var hardwareStats:' in entry.read_text():
                content = content.replace('open:true;triggerMode:"hover";anchorHovered:true}',
                                          'open:true;triggerMode:"hover";anchorHovered:true;hardwareStats:hw}')
            (folder / 'shell.qml').write_text(content)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CACHE_HOME=str(folder / 'cache'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '--no-color', '--path', str(folder)], env=env,
                                    capture_output=True, text=True, timeout=15)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertNotIn('UI-FAIL', log)
            self.assertNotIn('ERROR', log)
            count = re.search(r'UI-PASS (\d+) checks', log)
            self.assertIsNotNone(count, log)
            self.assertGreaterEqual(int(count[1]), 200, log)
            self.assertIn('MIDFRAME', log)


if __name__ == '__main__':
    unittest.main()
