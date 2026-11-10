#!/usr/bin/env python3
"""Check real subprocess failures, interruption evidence and capture boundaries."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('reference', Path(__file__).resolve().parents[1]/'scripts/reference.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.w = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_success_and_nonzero_not_run(self):
        self.assertEqual(r.run(self.w, 'configure', 'test', [sys.executable, '-c', 'pass']), 0)
        self.assertEqual(r.run(self.w, 'compile', 'test', [sys.executable, '-c', 'raise SystemExit(7)']), 7)
        phases = {e['phase']: e['status'] for e in r.phase_summary(self.w)}
        self.assertEqual(phases['configure'], 'PASS')
        self.assertEqual(phases['compile'], 'FAIL')
        self.assertEqual(phases['install'], 'NOT_RUN')

    def test_missing_program_fails(self):
        self.assertEqual(r.run(self.w, 'test', 'test', ['/nonexistent-pb-command']), 127)

    def test_signal_fails(self):
        self.assertEqual(r.run(self.w, 'test', 'test', [sys.executable, '-c', 'import os,signal; os.kill(os.getpid(),signal.SIGTERM)']), 143)

    def test_interrupted_start_incomplete(self):
        r.record(self.w, dict(event='start', index=0, phase='compile', project='test'))
        self.assertEqual(r.phase_summary(self.w)[0]['status'], 'INCOMPLETE')

    def test_unknown_phase_rejected(self):
        with self.assertRaises(ValueError):
            r.run(self.w, 'unknown', 'test', ['true'])

    def capture(self, mutate=None):
        (self.w/'build/test').mkdir(parents=True)
        (self.w/'repo/recipes/test').mkdir(parents=True)
        (self.w/'repo/recipes/test/build.sh').write_text('true')
        (self.w/'build/test/build.ninja').write_text('subninja CMakeFiles/rules.ninja\n')
        (self.w/'build/test/CMakeFiles').mkdir()
        (self.w/'build/test/CMakeFiles/rules.ninja').write_text('# rules')
        (self.w/'build/test/raw.log').write_text('must not be captured')
        (self.w/'result.json').write_text(json.dumps(dict(recipe='test',status='FAIL')))
        if mutate:
            mutate()
        # The tool version subprocesses are stubbed only after actual input checks.
        tc=self.w/'tc'
        for rel in ('host-utils/bin/cmake-4.4.3/bin/cmake','reference-tools/bin/ninja'):
            p=tc/rel; p.parent.mkdir(parents=True); p.write_text('#!/bin/sh\necho version\n'); p.chmod(0o755)
        r.capture(self.w, self.w/'repo', tc, self.w/'bundle', self.w/'result.json')
        return json.loads((self.w/'bundle/reference.json').read_text())

    def test_nested_ninja_included_logs_excluded(self):
        m=self.capture()
        paths=[e['path'] for e in m['files']]
        self.assertIn('build/test/CMakeFiles/rules.ninja', paths)
        self.assertFalse(any(p.endswith('raw.log') for p in paths))
        self.assertEqual(m['pinned_status'], 'NOT_RUN')

    def test_symlink_rejected(self):
        def mutate():
            p=self.w/'build/test/build.ninja'; p.unlink(); p.symlink_to('/etc/hostname')
        with self.assertRaises(ValueError):
            self.capture(mutate)


if __name__ == '__main__':
    unittest.main()
