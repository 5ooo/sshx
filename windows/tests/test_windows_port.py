#!/usr/bin/env python3
"""Exercise the PowerShell port with isolated profiles and a fake SSH transport.

Run with PWSH=/path/to/pwsh python3 windows/tests/test_windows_port.py.
The fake transport executes the generated remote key-install command locally.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get("PWSH", "pwsh")


class PowerShellPortTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sshx port ")
        self.root = Path(self.temp.name)
        self.home = self.root / "User Name"
        self.home.mkdir()
        self.remote = self.root / "remote home"
        self.remote.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "ssh.log"
        self.env = os.environ.copy()
        self.env.update({
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "SSHX_TEST_LOG": str(self.log),
            "SSHX_TEST_REMOTE": str(self.remote),
            "POWERSHELL_TELEMETRY_OPTOUT": "1",
        })
        (self.bin / "ssh").write_text('''#!/usr/bin/env python3
import json, os, subprocess, sys
with open(os.environ['SSHX_TEST_LOG'], 'a') as f: f.write(json.dumps(sys.argv[1:]) + "\\n")
if sys.argv[1:2] == ['-p']:
    if os.environ.get('SSHX_TEST_FAIL'):
        print('Simulated SSH error on stdout')
        sys.exit(17)
    env = os.environ.copy()
    env['HOME'] = os.environ['SSHX_TEST_REMOTE']
    sys.exit(subprocess.run(['/bin/sh', '-c', sys.argv[-1]], env=env).returncode)
sys.exit(int(os.environ.get('SSHX_TEST_CONNECT_EXIT', '0')))
''')
        (self.bin / "ssh").chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def ps(self, *args, expected=0, stdin=None, env=None):
        result = subprocess.run([PWSH, "-NoLogo", "-NoProfile", *args],
                                env=env or self.env, input=stdin, capture_output=True,
                                text=True, timeout=30)
        if result.returncode != expected:
            self.fail(f"PowerShell {args} returned {result.returncode}, expected {expected}\nstdout={result.stdout}\nstderr={result.stderr}")
        return result

    def sshx(self, *args, **kwargs):
        return self.ps("-File", str(ROOT / "src/sshx.ps1"), *args, **kwargs)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    @property
    def config(self):
        return self.home / ".ssh/config"

    def test_setup_reuse_rename_and_remove_preserve_configuration(self):
        self.config.parent.mkdir()
        outside = b"# user config\nHost external external-two\n    User somebody\nHost *\n    User defaultuser\n"
        self.config.write_bytes(outside)
        self.sshx("-p", "2222", "root@example.com", "dev-server")
        config = self.config.read_bytes()
        self.assertFalse(config.startswith(b'\xef\xbb\xbf'))
        self.assertTrue(config.endswith(outside))
        self.assertTrue((self.home / '.ssh/id_ed25519_sshx').exists())
        remote_key = (self.remote / '.ssh/authorized_keys').read_text()
        self.assertEqual(remote_key, (self.home / '.ssh/id_ed25519_sshx.pub').read_text())
        ssh_config = subprocess.run(['ssh', '-F', str(self.config), '-G', 'dev-server'],
                                    capture_output=True, text=True, check=True).stdout
        self.assertIn('hostname example.com\n', ssh_config)
        self.assertIn('user root\n', ssh_config)
        self.assertIn('port 2222\n', ssh_config)
        self.assertIn('identityfile ~/.ssh/id_ed25519_sshx\n', ssh_config)
        self.assertEqual(len(self.calls()), 2)
        self.sshx('root@example.com:2222')
        self.assertEqual(len(self.calls()), 3, 'the existing destination should not reinstall the key')
        self.assertIn('root@example.com:2222', self.sshx('list').stdout)
        text = self.config.read_text().replace('    IdentitiesOnly yes\n', '    IdentitiesOnly yes\n    Compression yes\n')
        self.config.write_text(text)
        self.sshx('mv', 'dev-server', 'renamed')
        self.assertIn('    Compression yes\n', self.config.read_text(), 'renaming should retain custom options')
        self.sshx('rm', 'renamed')
        self.assertNotIn('Host renamed', self.config.read_text())
        self.assertTrue(self.config.read_bytes().endswith(outside))

    def test_failed_overwrite_keeps_original_even_if_ssh_prints_output(self):
        self.sshx('root@first.example', 'dev')
        original = self.config.read_bytes()
        env = self.env.copy()
        env['SSHX_TEST_FAIL'] = '1'
        self.sshx('root@second.example', 'dev', stdin='y\n', env=env, expected=1)
        self.assertEqual(self.config.read_bytes(), original)

    def test_key_install_is_idempotent_for_different_hosts(self):
        self.sshx('root@first.example', 'first')
        self.sshx('root@second.example', 'second')
        self.assertEqual((self.remote / '.ssh/authorized_keys').read_text(),
                         (self.home / '.ssh/id_ed25519_sshx.pub').read_text())

    def test_legacy_native_argument_passing_and_quoted_key_comment(self):
        self.config.parent.mkdir()
        key = self.home / '.ssh/id_ed25519_sshx'
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-f', str(key), '-N', '', '-C', "o'brien"], check=True)
        script = str(ROOT / 'src/sshx.ps1').replace("'", "''")
        command = f"$PSNativeCommandArgumentPassing = 'Legacy'; & '{script}' -p 2222 root@example.com legacy"
        self.ps('-Command', command)
        self.assertEqual((self.remote / '.ssh/authorized_keys').read_text(), key.with_suffix('.pub').read_text())

    def test_alias_containing_dot_connects_without_setup(self):
        self.sshx('root@example.com', 'work.server')
        before = len(self.calls())
        self.sshx('work.server')
        self.assertEqual(len(self.calls()), before + 1)
        self.assertEqual(self.calls()[-1], ['work.server'])

    def test_conflicts_invalid_inputs_and_bad_markers_do_not_damage_files(self):
        self.config.parent.mkdir()
        external = b'Host one other\n    User keep\n'
        self.config.write_bytes(external)
        self.sshx('root@example.com', 'other', expected=1)
        self.assertEqual(self.config.read_bytes(), external)
        self.sshx('-p', '65536', 'root@example.com', expected=1)
        self.sshx('root@example.com', 'bad\nalias', expected=1)
        self.assertEqual(self.config.read_bytes(), external)
        malformed = external + b'# >>> sshx hosts >>>\nHost existing\n    User keep\n'
        self.config.write_bytes(malformed)
        self.sshx('rm', 'existing', expected=1)
        self.assertEqual(self.config.read_bytes(), malformed)
        utf16 = b'\xff\xfe' + 'Host protected\n    User keep\n'.encode('utf-16-le')
        self.config.write_bytes(utf16)
        self.sshx('root@example.com', 'new', expected=1)
        self.assertEqual(self.config.read_bytes(), utf16)

    def test_completion(self):
        self.sshx('root@example.com', 'dev-server')
        command = ". '" + str(ROOT / 'src/sshx-completion.ps1').replace("'", "''") + "'; Get-SshxCompletions 'de' | ForEach-Object CompletionText"
        self.assertEqual(self.ps('-Command', command).stdout.strip(), 'dev-server')

    def test_install_and_uninstall_keep_data_by_default(self):
        install = ROOT / 'scripts/install-sshx.ps1'
        uninstall = ROOT / 'scripts/uninstall-sshx.ps1'
        self.ps('-File', str(install))
        self.ps('-File', str(install))
        installed = self.home / '.local/bin'
        self.assertTrue((installed / 'sshx.cmd').exists())
        self.assertTrue((installed / 'sshx-main.ps1').exists())
        profiles = list(self.root.rglob('Microsoft.PowerShell_profile.ps1'))
        self.assertEqual(len(profiles), 1)
        self.assertEqual(profiles[0].read_text().count('# >>> sshx PowerShell setup >>>'), 1)
        self.sshx('root@example.com', 'saved')
        self.ps('-File', str(uninstall), '-Yes')
        self.assertFalse((installed / 'sshx.cmd').exists())
        self.assertNotIn('sshx PowerShell setup', profiles[0].read_text())
        self.assertIn('Host saved', self.config.read_text())
        self.assertTrue((self.home / '.ssh/id_ed25519_sshx').exists())
        self.ps('-File', str(uninstall), '-Yes', '-RemoveData')
        self.assertNotIn('# >>> sshx hosts >>>', self.config.read_text())
        self.assertFalse((self.home / '.ssh/id_ed25519_sshx').exists())

    def test_marked_block_preserves_other_bytes_for_common_encodings(self):
        helper = str(ROOT / 'scripts/sshx-marked-block.ps1').replace("'", "''")
        before = 'before 中文\r\n'
        after = 'after 中文\r\n'
        for name, encoding, bom in [('utf8', 'utf-8', b'\xef\xbb\xbf'),
                                    ('utf16le', 'utf-16-le', b'\xff\xfe'),
                                    ('utf16be', 'utf-16-be', b'\xfe\xff'),
                                    ('utf32le', 'utf-32-le', b'\xff\xfe\x00\x00')]:
            with self.subTest(encoding=name):
                path = self.root / (name + '.txt')
                original = bom + (before + after).encode(encoding)
                path.write_bytes(original)
                escaped = str(path).replace("'", "''")
                command = f"$ErrorActionPreference = 'Stop'; . '{helper}'; Set-SshxMarkedBlock -Path '{escaped}' -Begin '# begin' -End '# end' -Content 'managed'; Set-SshxMarkedBlock -Path '{escaped}' -Begin '# begin' -End '# end' -Remove"
                self.ps('-Command', command)
                self.assertEqual(path.read_bytes(), original)


if __name__ == '__main__':
    unittest.main(verbosity=2)
