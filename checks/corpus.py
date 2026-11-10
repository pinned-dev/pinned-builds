#!/usr/bin/env python3
"""Negative publication checks and real subprocess failure receipts."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('corpus',ROOT/'scripts/corpus.py')
c=importlib.util.module_from_spec(spec); spec.loader.exec_module(c)


class CorpusTests(unittest.TestCase):
    def test_inventory_covers_reviewed_unique_projects(self):
        entries=c.catalog()['packages']
        self.assertGreaterEqual(len(entries),50)
        self.assertEqual(len({e['repository'].lower() for e in entries}),len(entries))
        self.assertEqual(len(c.scope(campaign='pilot-50')['packages']),50)
        self.assertEqual(c.scope(campaign='inventory-100')['packages'],sorted(e['name'] for e in entries))
        self.assertEqual(set(c.scope(campaign='expansion-100')['packages']) | set(c.scope(campaign='pilot-50')['packages']), {e['name'] for e in entries})
        self.assertFalse(set(c.scope(campaign='expansion-100')['packages']) & set(c.scope(campaign='pilot-50')['packages']))

    def mutated_catalog(self,mutate):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); shutil.copytree(ROOT/'corpus',root/'corpus')
            p=root/'corpus/packages.json'; data=json.loads(p.read_text()); mutate(data); p.write_text(json.dumps(data))
            with self.assertRaises(ValueError): c.catalog(root)

    def test_duplicate_package_rejected(self):
        self.mutated_catalog(lambda d:d['packages'].append(d['packages'][0]))

    def test_license_escape_rejected(self):
        self.mutated_catalog(lambda d:d['packages'][0].update(license_files=['../secret']))

    def test_hook_path_escape_rejected(self):
        self.mutated_catalog(lambda d:d['packages'][0].update(cmake_hook='../outside.cmake'))

    def test_source_url_drift_rejected(self):
        self.mutated_catalog(lambda d:d['packages'][0].update(url='https://example.org/archive'))

    def test_option_drift_rejected(self):
        self.mutated_catalog(lambda d:d['packages'][0]['defines'].append('NEW_FLAG=ON'))

    def test_credentials_rejected(self):
        self.assertIn('credential-pattern',c.privacy.problems(('github_'+'pat_'+'a'*30).encode()))

    def test_private_home_rejected(self):
        self.assertIn('personal-home-path',c.privacy.problems(('/home/'+'test-user'+'/src').encode()))
        self.assertFalse(c.privacy.problems(b'/home/runner/work/public-repo'))

    def test_private_workspace_rejected(self):
        self.assertIn('private-work-path',c.privacy.problems(('/work/'+'task-data').encode()))

    def test_ip_and_internal_host_rejected(self):
        address='.'.join(map(str,[192,168,12,8]))
        self.assertIn('ip-address',c.privacy.problems(address.encode()))
        self.assertIn('internal-hostname',c.privacy.problems(('build'+'.internal').encode()))
        self.assertIn('ip-address',c.privacy.problems(('fd00'+':'*2+'1').encode()))

    def test_cmake_target_ids_are_not_ip_addresses(self):
        for value in ('curl-example-websocket-cb::@abc123','curl-generate-config.1::@abc123'):
            self.assertNotIn('ip-address',c.privacy.problems(value.encode()))

    def test_email_rejected_but_license_preserved(self):
        address=('contact'+'@'+'example.org').encode()
        self.assertIn('personal-email',c.privacy.problems(address))
        self.assertFalse(c.privacy.problems(address,legal_notice=True))

    def test_symlink_not_followed(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); (root/'link').symlink_to('/etc/passwd')
            self.assertEqual(c.privacy.scan(root)['findings'][0]['reasons'],['symlink'])

    def test_nul_rejected(self):
        self.assertIn('nul-byte',c.privacy.problems(b'abc\0def'))

    def subprocess_case(self,script,expected,timeout=10):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); (root/'scripts').mkdir(); (root/'tc').mkdir()
            p=root/'scripts/build-recipe.sh'; p.write_text('#!/bin/sh\n'+script+'\n'); p.chmod(0o755)
            entry={'name':'test','repository':'https://github.com/example/public','version':'v1','commit':'a'*40,'sha256':'b'*64,'license':'MIT','feature_tags':['c']}
            with mock.patch.object(c,'ROOT',root),mock.patch.object(c,'catalog',return_value={'packages':[entry]}),contextlib.redirect_stdout(io.StringIO()):
                rc=c.capture('test',root/'tc',root/'work',root/'out',local=True,timeout=timeout)
            result=json.loads((root/'out/capture.json').read_text())
            self.assertNotEqual(rc,0); self.assertEqual(result['status'],expected)
            self.assertEqual(result['pinned_status'],'NOT_RUN')
            self.assertEqual(list((root/'out').iterdir()),[root/'out/capture.json'])

    def test_exit_zero_without_manifest_is_infra_error(self):
        self.subprocess_case('exit 0','INFRA_ERROR')

    def test_real_source_failure_is_not_pass(self):
        self.subprocess_case('echo "download failed:"; exit 2','SOURCE_FAIL')

    def test_real_configure_failure_is_not_pass(self):
        self.subprocess_case('echo \'{"status":"FAIL","phases":[{"phase":"configure","status":"FAIL","returncode":7}]}\' > "$4"; exit 7','CONFIGURE_FAIL')

    def test_missing_capture_after_native_pass_fails(self):
        self.subprocess_case('echo \'{"status":"PASS","phases":[]}\' > "$4"; exit 0','CAPTURE_FAIL')

    def test_real_timeout_is_not_pass(self):
        self.subprocess_case('sleep 5','TIMEOUT',timeout=.05)


    def reference_fixture(self,root):
        files={
            'build/test/build.ninja':b'build all: phony\n',
            'result.json':json.dumps({'phases':[],'source':{}}).encode(),
            'reference/introspection/test/targets.txt':b'all: phony\n',
            'reference/introspection/test/rules.txt':b'phony\n',
            'build/test/.cmake/api/v1/reply/model.json':b'{"configurations":[]}',
        }
        objects=[{'kind':kind,'jsonFile':'model.json'} for kind in ('codemodel','cache','cmakeFiles','toolchains')]
        files['build/test/.cmake/api/v1/reply/index-test.json']=json.dumps({'objects':objects}).encode()
        entries=[]
        for rel,data in files.items():
            p=root/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(data)
            entries.append({'path':rel,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        m={'schema':'pinned-builds/native-reference/v1','recipe':'test','native_status':'PASS','pinned_status':'NOT_RUN','visibility':'public-native','phases':[],'roots':{'work':'/sample/work','repository':'/sample/repo','toolchain':'/sample/tools'},'files':entries,'introspection':[{'project':'test','tool':tool,'rows':1} for tool in ('targets','rules')]}
        (root/'reference.json').write_text(json.dumps(m))
        return m

    def test_graph_byte_tamper_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); self.reference_fixture(root)
            self.assertEqual(c.inspect_reference(root,'test')['ninja_targets'],1)
            (root/'build/test/build.ninja').write_text('build other: phony\n')
            with self.assertRaises(ValueError): c.inspect_reference(root,'test')

    def test_unlisted_file_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); self.reference_fixture(root); (root/'extra').write_text('extra')
            with self.assertRaises(ValueError): c.inspect_reference(root,'test')

    def test_empty_symlink_directory_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); self.reference_fixture(root); (root/'link').symlink_to(root/'missing',target_is_directory=True)
            with self.assertRaises(ValueError): c.inspect_reference(root,'test')

    def test_forged_node_count_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); m=self.reference_fixture(root); m['introspection'][0]['rows']=100
            (root/'reference.json').write_text(json.dumps(m))
            with self.assertRaises(ValueError): c.inspect_reference(root,'test')

    def test_download_missing_hidden_file_api_fails_summary(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); package=root/'test'; reference=package/'reference'; reference.mkdir(parents=True)
            self.reference_fixture(reference)
            stats=c.inspect_reference(reference,'test')
            upstream={'repository':'https://github.com/example/public','version':'v1','commit':'a'*40,'sha256':'b'*64,'license':'MIT'}
            receipt={'schema':'pinned-builds/capture-result/v1','package':'test','status':'CAPTURED','publication':'CHECKED','build_status':'NOT_RUN','test_status':'NOT_RUN','pinned_status':'NOT_RUN','upstream':upstream,'capture':stats,'phases':[],'source':{},'declared_feature_tags':['c']}
            (package/'capture.json').write_text(json.dumps(receipt))
            with mock.patch.object(c,'catalog',return_value={'packages':[dict(upstream,name='test')]}):
                self.assertTrue(c.verify_capture(package,public=True)['valid'])
                shutil.rmtree(reference/'build/test/.cmake')
                self.assertEqual(c.summarize(root,1,root/'summary'),1)
            metrics=json.loads((root/'summary/metrics.json').read_text())
            self.assertEqual(metrics['counts']['CAPTURE_FAIL'],1)
            self.assertEqual(metrics['results'][0]['reported_status'],'CAPTURED')
            self.assertEqual(metrics['results'][0]['reason'],'downloaded-artifact-validation')

    def test_missing_receipts_fail_summary(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); output=root/'summary'
            self.assertEqual(c.summarize(root,len(c.catalog()['packages']),output),1)
            self.assertEqual(json.loads((output/'metrics.json').read_text())['counts']['MISSING'],len(c.catalog()['packages']))


    def test_batch_partition_is_complete_disjoint_and_repeatable(self):
        full=c.scope(campaign='pilot-50')['packages']
        parts=[c.scope(campaign='pilot-50',batch=f'{i}/3')['packages'] for i in range(1,4)]
        self.assertEqual(sorted(n for part in parts for n in part),full)
        self.assertEqual(len(set(n for part in parts for n in part)),len(full))
        self.assertEqual(parts[0],c.scope(campaign='pilot-50',batch='1/3')['packages'])

    def test_scope_tamper_rejected(self):
        for field,value in [('catalog_sha256','0'*64),('packages',['fmt']),('batch','9/9')]:
            scope=c.scope(campaign='pilot-50'); scope[field]=value
            with self.assertRaises(ValueError):c.validate_scope(scope)

    def test_bad_batch_or_selection_rejected(self):
        for batch in ('0/2','3/2','1/0','1/999','../2','1/2/3'):
            with self.assertRaises(ValueError):c.scope(campaign='pilot-50',batch=batch)
        with self.assertRaises(ValueError):c.scope(only='fmt',campaign='pilot-50')
        with self.assertRaises(ValueError):c.scope(campaign='../outside')

    def test_wrong_batch_member_cannot_replace_missing_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'wrong').mkdir()
            (root/'wrong/capture.json').write_text(json.dumps({'schema':'pinned-builds/capture-result/v1','package':'zstd','status':'SOURCE_FAIL'}))
            selected=c.scope(only='fmt')
            with self.assertRaises(ValueError):c.summarize(root,1,root/'out',selected)

    def test_count_without_matching_inventory_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):c.summarize(Path(directory),1,Path(directory)/'out')

    def test_mixed_run_receipt_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'fmt').mkdir()
            (root/'fmt/capture.json').write_text(json.dumps({'schema':'pinned-builds/capture-result/v1','package':'fmt','status':'SOURCE_FAIL','source':{'run_id':'wrong'}}))
            with self.assertRaises(ValueError):c.summarize(root,1,root/'out',c.scope(only='fmt'),{'run_id':'expected'})

    def test_missing_scope_reports_exact_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); value=c.scope(campaign='expansion-100',batch='2/2')
            self.assertEqual(c.summarize(root,len(value['packages']),root/'out',value),1)
            metrics=json.loads((root/'out/metrics.json').read_text())
            self.assertEqual(metrics['expected_packages'],value['packages'])
            self.assertEqual(metrics['missing_packages'],value['packages'])
            self.assertEqual(metrics['counts']['MISSING'],25)

    def test_duplicate_or_unknown_campaign_member_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);shutil.copytree(ROOT/'corpus',root/'corpus')
            path=root/'corpus/campaigns/pilot-50.json';original=json.loads(path.read_text())
            for names in ([original['packages'][0]]*2,['unknown-package']):
                value=dict(original,packages=names);path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):c.scope(campaign='pilot-50',root=root)

    def test_large_catalog_requires_and_accepts_partition(self):
        packages=[{'name':f'package-{i:04}'} for i in range(2000)]
        with mock.patch.object(c,'catalog',return_value={'packages':packages}):
            with self.assertRaises(ValueError):c.scope(only='all')
            parts=[c.scope(only='all',batch=f'{i}/8')['packages'] for i in range(1,9)]
            self.assertEqual([len(part) for part in parts],[250]*8)
            self.assertEqual(len(set(n for part in parts for n in part)),2000)

if __name__=='__main__': unittest.main()
