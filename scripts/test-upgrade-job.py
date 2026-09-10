#!/usr/bin/env python3
"""Sandboxed lifecycle test: every sysupgrade invocation is a fake executable."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

src = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='xr-upgrade-test-') as directory:
    root = Path(directory)
    helper = root / 'helper'
    stub = root / 'sysupgrade-stub'
    image = root / 'firmware.bin'
    image.write_text('NOT A FLASH IMAGE')
    shell = (src / 'files/usr/libexec/xr1710g-upgrade').read_text()
    for key, value in {'SELF': helper, 'JOB': root / 'job', 'CONTROL': root / 'control',
                       'IMAGE': image, 'UPGRADE': stub}.items():
        import re
        shell = re.sub(r'^' + key + '=.*$', key + '=' + str(value), shell, flags=re.M)
    helper.write_text(shell)
    helper.chmod(0o755)
    stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > ' + str(root / 'args') +
                    '\nsleep 35\necho "SIMULATED BACKUP ERROR" >&2\nexit 42\n')
    stub.chmod(0o755)

    def run(*args):
        return subprocess.run([str(helper), *args], text=True, capture_output=True, timeout=5)

    assert json.loads(run('status').stdout)['state'] == 'idle'
    for args in [('start', '--command'), ('start', '/tmp/other'), ('start', '-n', '-n'),
                 ('start', ';reboot'), ('clear', 'invalid')]:
        assert run(*args).returncode != 0, args
    assert not (root / 'job').exists()
    begin = time.monotonic()
    result = run('start', '--force', '-u', '-k')
    assert result.returncode == 0, result.stderr
    assert time.monotonic() - begin < 5, 'launcher waited for backup'
    job = json.loads(result.stdout)
    assert job['state'] in ('queued', 'running')
    assert run('start').returncode != 0, 'duplicate job accepted'
    assert run('clear', job['id']).returncode != 0, 'active job cleared'
    time.sleep(31)
    assert json.loads(run('status').stdout)['state'] == 'running', 'worker died at old 30s limit'
    print('PASS: detached worker survives 30-second RPC window', flush=True)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        status = json.loads(run('status').stdout)
        if status['state'] == 'failed':
            break
        time.sleep(.25)
    assert status['state'] == 'failed' and status['code'] == 42
    assert (root / 'args').read_text().splitlines() == ['--force', '-u', '-k', str(image)]
    assert 'SIMULATED BACKUP ERROR' in (root / 'job/output.log').read_text()
    assert run('clear', 'other-id').returncode != 0
    # A child may remain a zombie briefly in a container. Reap-aware kill -0
    # prevents clearing rather than permitting concurrent upgrades; test cleanup
    # checks that no actual worker remains before removing this private PID file.
    pid = int((root / 'job/pid').read_text())
    proc = Path(f'/proc/{pid}/stat')
    for _ in range(20):
        if not proc.exists() or proc.read_text().split(') ')[1].startswith('Z '):
            break
        time.sleep(.1)
    assert not proc.exists() or proc.read_text().split(') ')[1].startswith('Z ')
    (root / 'job/pid').unlink(missing_ok=True)
    assert run('clear', job['id']).returncode == 0
    assert json.loads(run('status').stdout)['state'] == 'idle'
    stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > ' + str(root / 'args') + '\nexit 0\n')
    job = json.loads(run('start', '-n').stdout)
    time.sleep(1)
    assert json.loads(run('status').stdout)['state'] == 'handoff'
    assert json.loads(run('status').stdout)['keep'] == 0
    assert (root / 'args').read_text().splitlines() == ['-n', str(image)]
    assert run('clear', job['id']).returncode != 0, 'handoff was treated as retryable'
    assert not (root / 'control').exists()
    assert (root / 'job').stat().st_mode & 0o777 == 0o700
    (root / 'job/state').write_text('running\n')
    (root / 'job/started').write_text('0\n')
    (root / 'job/pid').write_text('99999999\n')
    assert json.loads(run('status').stdout)['state'] == 'unknown'
    assert run('clear', job['id']).returncode != 0, 'lost worker was treated as safe retry'
    print('PASS: whitelist, option preservation, mutual exclusion, failure details, explicit clear, no automatic retry, no-config handoff, private files')
    print('PASS: preserved reset mode, lost-worker uncertainty blocks retry')
