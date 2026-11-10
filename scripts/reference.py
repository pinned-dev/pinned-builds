#!/usr/bin/env python3
"""Local native evidence. Raw graphs/argv are NOT public result manifests."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import time

SCHEMA = 'pinned-builds/native-reference/v1'
PHASES = ('configure', 'compile', 'test', 'install', 'smoke-configure', 'smoke-compile', 'smoke-run')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    tmp.replace(path)


def events(work):
    path = work / 'reference/events.jsonl'
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def record(work, event):
    path = work / 'reference/events.jsonl'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as f:
        f.write(json.dumps(event) + '\n')


def run(work, phase, project, argv):
    if phase not in PHASES or not argv or not re.fullmatch(r'[a-z0-9][a-z0-9-]*', project):
        raise ValueError('unknown phase or empty command')
    start = time.time()
    index = len(events(work))
    record(work, dict(event='start', index=index, phase=phase, project=project,
                      argv=argv, started=start))
    try:
        rc = subprocess.call(argv)
    except OSError:
        rc = 127
    record(work, dict(event='finish', index=index, phase=phase, project=project,
                      returncode=rc, finished=time.time(), duration_seconds=time.time()-start))
    return rc if rc >= 0 else 128 - rc


def phase_summary(work):
    rows = []
    pending = {}
    for e in events(work):
        if e['event'] == 'start':
            row = {k: e[k] for k in ('index', 'phase', 'project')}
            row['status'] = 'INCOMPLETE'
            rows.append(row)
            pending[e['index']] = row
        elif e['event'] == 'finish':
            row = pending.pop(e['index'])
            row.update(status='PASS' if e['returncode'] == 0 else 'FAIL',
                       returncode=e['returncode'], duration_seconds=e['duration_seconds'])
    for phase in PHASES:
        if not any(r['phase'] == phase for r in rows):
            rows.append(dict(phase=phase, project=None, status='NOT_RUN'))
    return rows


def capture(work, repo, tc, output, result):
    """Copy allowlisted generated metadata only, never follow symlinks."""
    if output.exists():
        raise ValueError('reference output already exists')
    output.mkdir(parents=True)
    files = []
    total = 0
    max_bytes = 128 * 1024 * 1024
    def add(source, rel):
        nonlocal total
        if source.is_symlink() or not source.is_file():
            raise ValueError('non-regular reference input')
        # Check all ancestors, including an attacker-replaced build directory.
        if source.resolve() != source.absolute():
            raise ValueError('symlink in reference input path')
        size = source.stat().st_size
        total += size
        if total > max_bytes or len(files) >= 10000:
            raise ValueError('reference size limit')
        dest = output / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        files.append(dict(path=rel, size=size, sha256=digest(dest)))
    build = work / 'build'
    if build.exists():
        for base, dirs, names in os.walk(build, followlinks=False):
            dirs[:] = sorted(d for d in dirs if not (Path(base)/d).is_symlink())
            for name in sorted(names):
                p = Path(base)/name
                rel = p.relative_to(work)
                # Include every generated .ninja fragment, not just build.ninja.
                if name.endswith('.ninja') or name == 'compile_commands.json' or (
                    '/.cmake/api/v1/reply/' in '/' + rel.as_posix() and name.endswith('.json')):
                    add(p, rel.as_posix())
    for rel in ('reference/events.jsonl', 'toolchain.cmake'):
        p = work / rel
        if p.exists():
            add(p, rel)
    # Source recipe files are needed for replay but remain under their own licenses.
    manifest = json.loads(result.read_text())
    recipe_dir = repo / 'recipes' / manifest['recipe']
    for base, dirs, names in os.walk(recipe_dir, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not (Path(base)/d).is_symlink())
        for name in sorted(names):
            p = Path(base)/name
            add(p, p.relative_to(repo).as_posix())
    add(result, 'result.json')
    versions = {}
    for name, rel in (('cmake', 'host-utils/bin/cmake-4.4.3/bin/cmake'),
                      ('ninja', 'reference-tools/bin/ninja')):
        tool = tc / rel
        versions[name] = dict(sha256=digest(tool), version=subprocess.check_output(
            [str(tool), '--version'], text=True).splitlines()[0])
    write(output / 'reference.json', dict(schema=SCHEMA, evidence_class='native-reference',
          visibility='local-only', recipe=manifest['recipe'], native_status=manifest['status'],
          pinned_status='NOT_RUN', mode=os.environ.get('PB_MODE', 'full'),
          roots=dict(work=str(work), repository=str(repo), toolchain=str(tc)),
          tools=versions, phases=phase_summary(work), files=files,
          limitations=['Generated graphs may contain absolute paths; reconfigure for replay.',
                        'No source archives or built libraries are redistributed.',
                        'Native evidence does not establish a Pinned result.']))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='action', required=True)
    r = sub.add_parser('run')
    r.add_argument('work', type=Path)
    r.add_argument('phase', choices=PHASES)
    r.add_argument('project')
    r.add_argument('argv', nargs=argparse.REMAINDER)
    c = sub.add_parser('capture')
    for name in ('work', 'repo', 'toolchain', 'output', 'result'):
        c.add_argument('--' + name, required=True, type=Path)
    a = p.parse_args()
    if a.action == 'run':
        return run(a.work, a.phase, a.project, a.argv)
    capture(a.work, a.repo, a.toolchain, a.output, a.result)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
