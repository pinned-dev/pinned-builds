#!/usr/bin/env python3
"""Curated native configure captures; never invokes the Pinned product."""
import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import time
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
_spec=importlib.util.spec_from_file_location('public_check', ROOT/'scripts/public_check.py')
privacy=importlib.util.module_from_spec(_spec); _spec.loader.exec_module(privacy)
STATES=('CAPTURED','CONFIGURE_FAIL','SOURCE_FAIL','TIMEOUT','INFRA_ERROR','CAPTURE_FAIL')


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+'\n')


def safe_relative(value):
    p=PurePosixPath(value)
    return bool(value) and not p.is_absolute() and p.as_posix()==value and '..' not in p.parts and '\\' not in value


def catalog(root=ROOT):
    data=json.loads((root/'corpus/packages.json').read_text())
    if data['schema']!='pinned-builds/capture-catalog/v1': raise ValueError('catalog-schema')
    entries=data['packages']; names=set()
    for e in entries:
        name=e['name']
        if not re.fullmatch('[a-z0-9][a-z0-9-]*',name) or name in names: raise ValueError('catalog-name')
        names.add(name)
        if not re.fullmatch('[0-9a-f]{40}',e['commit']) or not re.fullmatch('[0-9a-f]{64}',e['sha256']): raise ValueError('catalog-digest')
        owner_repo=e['repository'].removeprefix('https://github.com/')
        if not re.fullmatch('[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',owner_repo): raise ValueError('catalog-repository')
        if e['url']!=f"https://codeload.github.com/{owner_repo}/tar.gz/{e['commit']}": raise ValueError('catalog-source-url')
        if not re.fullmatch('[A-Za-z0-9][A-Za-z0-9._-]*',e['archive_top']): raise ValueError('catalog-archive-root')
        if e['cmake_subdir'] and not safe_relative(e['cmake_subdir']): raise ValueError('catalog-cmake-path')
        if not e['license_files'] or any(not safe_relative(p) for p in e['license_files']): raise ValueError('catalog-license-path')
        if any(not re.fullmatch('[A-Za-z0-9_]+=[A-Za-z0-9_.:+/-]+',v) for v in e['defines']): raise ValueError('catalog-option')
        recipe=root/'corpus/recipes'/name
        source=(recipe/'sources.txt').read_text().splitlines()[-1].split()
        if source[:3]!=[name,e['sha256'],e['archive_top']] or source[-1]!=e['url']: raise ValueError('recipe-source-drift')
        script=(recipe/'build.sh').read_text()
        if e.get('cmake_hook'):
            hook=e['cmake_hook']
            if not safe_relative(hook) or not (recipe/hook).is_file() or (recipe/hook).is_symlink(): raise ValueError('catalog-hook')
            if '-DCMAKE_PROJECT_INCLUDE="$PB_RECIPE_DIR/'+hook+'"' not in script: raise ValueError('recipe-hook-drift')
        # Option drift is an error, not a silent change in sample identity.
        if re.findall(r'-D([A-Za-z0-9_]+=[A-Za-z0-9_.:+/-]+)',script)!=e['defines']: raise ValueError('recipe-option-drift')
    return data


def inspect_reference(reference, package):
    refpath=reference/'reference.json'
    if refpath.is_symlink() or refpath.resolve()!=refpath.absolute() or refpath.stat().st_size>4*1024*1024: raise ValueError('reference-manifest')
    ref=json.loads(refpath.read_text())
    if ref['schema']!='pinned-builds/native-reference/v1' or ref['pinned_status']!='NOT_RUN' or ref['recipe']!=package or ref['native_status']!='PASS': raise ValueError('reference-schema')
    total=0; listed=set()
    for e in ref['files']:
        rel=e['path']
        if not safe_relative(rel) or rel in listed: raise ValueError('reference-path')
        listed.add(rel); p=reference/rel
        if p.is_symlink() or p.resolve()!=p.absolute() or not p.is_file(): raise ValueError('reference-file')
        data=p.read_bytes(); total+=len(data)
        if len(data)!=e['size'] or hashlib.sha256(data).hexdigest()!=e['sha256']: raise ValueError('reference-digest')
    if len(listed)>10000 or total>128*1024*1024: raise ValueError('reference-limit')
    nodes=list(reference.rglob('*'))
    if any(p.is_symlink() or not (p.is_file() or p.is_dir()) for p in nodes): raise ValueError('reference-node')
    actual={p.relative_to(reference).as_posix() for p in nodes if p.is_file()}
    if actual!=listed|{'reference.json'}: raise ValueError('reference-inventory')
    prefix='build/'+package+'/'
    if prefix+'build.ninja' not in listed: raise ValueError('graph-missing')
    indices=sorted((reference/'build'/package/'.cmake/api/v1/reply').glob('index-*.json'))
    if len(indices)!=1: raise ValueError('file-api-index')
    index=json.loads(indices[0].read_text()); kinds={e['kind'] for e in index.get('objects',[])}
    if not {'codemodel','cache','cmakeFiles','toolchains'}<=kinds: raise ValueError('file-api-incomplete')
    types=Counter()
    for obj in index['objects']:
        if obj['kind']!='codemodel': continue
        if not safe_relative(obj['jsonFile']): raise ValueError('file-api-path')
        model=json.loads((indices[0].parent/obj['jsonFile']).read_text())
        for config in model.get('configurations',[]):
            for target in config.get('targets',[]):
                if not safe_relative(target['jsonFile']): raise ValueError('file-api-path')
                t=json.loads((indices[0].parent/target['jsonFile']).read_text())
                types[t['type']]+=1
    # Comparison view only: retain original bytes and inventory as authority.
    graph_hash=hashlib.sha256()
    roots=sorted(((value,'<'+key.upper()+'>') for key,value in ref['roots'].items()),key=lambda p:len(p[0]),reverse=True)
    for rel in sorted(p for p in listed if p.endswith('.ninja')):
        text=(reference/rel).read_text()
        for source,logical in roots: text=text.replace(source,logical)
        graph_hash.update(rel.encode()+b'\0'+text.encode()+b'\0')
    introspection={}
    for tool in ('targets','rules'):
        rel=f'reference/introspection/{package}/{tool}.txt'
        if rel not in listed: raise ValueError('introspection-missing')
        introspection[tool]=len((reference/rel).read_bytes().splitlines())
    reported={e['tool']:e['rows'] for e in ref.get('introspection',[]) if e['project']==package}
    if reported!=introspection: raise ValueError('introspection-count')
    return {'graph_view_sha256':graph_hash.hexdigest(),'files':len(listed),'bytes':total,'ninja_fragments':sum(p.endswith('.ninja') for p in listed),
            'file_api_objects':sorted(kinds),'compilation_database':'PRESENT' if prefix+'compile_commands.json' in listed else 'NOT_GENERATED',
            'cmake_target_types':dict(types),'ninja_targets':introspection['targets'],
            'ninja_rules':introspection['rules'],
            'reference_sha256':hashlib.sha256((reference/'reference.json').read_bytes()).hexdigest()}


def capture(name,tc,work,output,local=False,timeout=600):
    entries=catalog()['packages']; package=next((e for e in entries if e['name']==name),None)
    if package is None: raise ValueError('unknown-package')
    work=work.absolute(); output=output.absolute(); tc=tc.resolve(strict=True)
    if work.exists() or output.exists(): raise ValueError('existing-work-or-output')
    if work.parent.resolve()!=work.parent or output.parent.resolve()!=output.parent: raise ValueError('symlink-work-or-output')
    output.mkdir(); reference=output/'reference'
    native_result=work.parent/(work.name+'-native.json')
    log=work.parent/(work.name+'-configure.log')
    env=dict(os.environ,PB_MODE='configure',PB_RECIPE_SET='corpus',PB_REFERENCE_OUT=str(reference),
             PB_REFERENCE_VISIBILITY='local-only' if local else 'public-native')
    start=time.monotonic(); timed_out=False
    with log.open('wb') as stream:
        proc=subprocess.Popen([str(ROOT/'scripts/build-recipe.sh'),name,str(tc),str(work),str(native_result)],env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        try: rc=proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out=True
            os.killpg(proc.pid,signal.SIGTERM)
            try: proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid,signal.SIGKILL); proc.wait()
            rc=124
    state='TIMEOUT' if timed_out else 'INFRA_ERROR'; reason='timeout' if timed_out else 'native-manifest-missing'
    phases=[]; stats={}
    if native_result.is_file() and not timed_out:
        m=json.loads(native_result.read_text()); phases=m['phases']
        if m['status']!='PASS': state='CONFIGURE_FAIL'; reason='native-configure-nonzero'
        elif rc: state='CAPTURE_FAIL'; reason='native-capture-nonzero'
        else:
            try:
                configure=[p for p in phases if p['phase']=='configure']
                if m.get('schema')!='pinned-builds/result-manifest/v1' or m.get('recipe')!=name or m.get('recipe_set')!='corpus' or m.get('mode')!='configure' or m.get('build_input_check')!='NOT_RUN':
                    raise ValueError('native-result-identity')
                if len(configure)!=1 or configure[0]['status']!='PASS' or configure[0]['project']!=name or any(p['status']!='NOT_RUN' for p in phases if p['phase']!='configure'):
                    raise ValueError('native-phase-contract')
                stats=inspect_reference(reference,name)
                state='CAPTURED'; reason=None
            except (ValueError,KeyError,OSError,json.JSONDecodeError):
                state='CAPTURE_FAIL'; reason='reference-validation'
    elif not timed_out:
        # Read only a fixed prefix, never publish the raw log or error text.
        text=log.read_text(errors='replace')
        if any(marker in text for marker in ('download failed:','sha256 mismatch:','unpack failed','unexpected top-level')):
            state='SOURCE_FAIL'; reason='source-preparation'
    privacy_failure_counts={}
    publication='LOCAL_ONLY' if local else 'PENDING'
    if state=='CAPTURED' and not local:
        try:
            findings=privacy.scan(reference)['findings']
            if findings:
                privacy_failure_counts=dict(Counter(reason for finding in findings for reason in finding['reasons']))
                state='CAPTURE_FAIL'; reason='privacy-check'
            else: publication='CHECKED'
        except (ValueError,OSError): state='CAPTURE_FAIL'; reason='privacy-check'
    if state!='CAPTURED' and reference.exists():
        # Only our newly created reference payload is disposable. Never upload
        # partial, invalid or privacy-rejected bytes.
        if reference.is_symlink(): reference.unlink()
        else: shutil.rmtree(reference)
    result={'schema':'pinned-builds/capture-result/v1','package':name,'profile':'linux-x86_64-release-configure',
            'status':state,'reason':reason,'publication':publication if state=='CAPTURED' else 'RECEIPT_ONLY',
            'privacy_failure_counts':privacy_failure_counts,'returncode':rc,'duration_seconds':time.monotonic()-start,'source':{'repository':env.get('GITHUB_REPOSITORY'),'commit':env.get('GITHUB_SHA'),'ref':env.get('GITHUB_REF'),'run_id':env.get('GITHUB_RUN_ID'),'run_attempt':env.get('GITHUB_RUN_ATTEMPT')},
            'upstream':{k:package[k] for k in ('repository','version','commit','sha256','license')},
            'declared_feature_tags':package['feature_tags'],'phases':phases,'capture':stats,
            'build_status':'NOT_RUN','test_status':'NOT_RUN','pinned_status':'NOT_RUN'}
    write(output/'capture.json',result)
    if not local:
        findings=privacy.scan(output)
        if findings['findings']: raise ValueError('receipt-privacy-check')
    summary=os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary,'a') as f:
            f.write(f"## Native capture: {name}\n\nStatus: **{state}**; graph nodes: {stats.get('ninja_targets',0)}; captured files: {stats.get('files',0)}.\n\nBuild/test/Pinned: NOT_RUN.\n")
    print(json.dumps({'package':name,'status':state,'reason':reason,'capture':stats}))
    return 0 if state=='CAPTURED' else 1


def verify_capture(output, expected_sha=None, public=False):
    path=output/'capture.json'
    if path.is_symlink() or path.resolve()!=path.absolute(): raise ValueError('receipt-path')
    data=path.read_bytes()
    if len(data)>4*1024*1024: raise ValueError('receipt-size')
    actual_sha=hashlib.sha256(data).hexdigest()
    if expected_sha and actual_sha!=expected_sha: raise ValueError('receipt-anchor')
    result=json.loads(data)
    if result['schema']!='pinned-builds/capture-result/v1' or result['status']!='CAPTURED' or any(result[k]!='NOT_RUN' for k in ('build_status','test_status','pinned_status')):
        raise ValueError('receipt-contract')
    package=next(e for e in catalog()['packages'] if e['name']==result['package'])
    if result['upstream']!={k:package[k] for k in ('repository','version','commit','sha256','license')}: raise ValueError('receipt-upstream')
    stats=inspect_reference(output/'reference',result['package'])
    if stats!=result['capture']: raise ValueError('receipt-statistics')
    ref=json.loads((output/'reference/reference.json').read_text())
    native=json.loads((output/'reference/result.json').read_text())
    if native['phases']!=result['phases'] or native['phases']!=ref['phases'] or native['source']!=result['source']: raise ValueError('receipt-native-mismatch')
    if public and (result['publication']!='CHECKED' or ref['visibility']!='public-native' or privacy.scan(output)['findings']): raise ValueError('publication-check')
    return {'package':result['package'],'valid':True,'capture_sha256':actual_sha,'origin_anchored':bool(expected_sha),'capture':stats}


def summarize(root,expected,output):
    results=[]
    for path in sorted(root.rglob('capture.json')):
        r=json.loads(path.read_text())
        if r.get('schema')!='pinned-builds/capture-result/v1' or r['status'] not in STATES: raise ValueError('summary-receipt')
        if r['status']=='CAPTURED':
            try:
                verify_capture(path.parent,public=True)
            except (ValueError,KeyError,OSError,StopIteration,json.JSONDecodeError):
                # Preserve the original receipt in the package artifact. The
                # aggregate records a separate post-download validation failure.
                r=dict(r,reported_status='CAPTURED',status='CAPTURE_FAIL',reason='downloaded-artifact-validation')
        results.append(r)
    selected={e['name'] for e in catalog()['packages']}
    by_name={r['package']:r for r in results}
    if len(by_name)!=len(results) or not set(by_name)<=selected: raise ValueError('summary-duplicate-or-unknown')
    counts=Counter(r['status'] for r in results)
    counts.update({'MISSING':max(0,expected-len(results))})
    tags=Counter(t for r in results if r['status']=='CAPTURED' for t in r['declared_feature_tags'])
    metrics={'schema':'pinned-builds/capture-summary/v1','expected':expected,'received':len(results),'counts':dict(counts),'declared_feature_tags_captured':dict(sorted(tags.items())),
             'captured_bytes':sum(r['capture'].get('bytes',0) for r in results if r['status']=='CAPTURED'),
             'ninja_targets':sum(r['capture'].get('ninja_targets',0) for r in results if r['status']=='CAPTURED'),
             'builds_executed':0,'tests_executed':0,'pinned_executions':0,'results':results}
    write(output/'metrics.json',metrics)
    rows=['# Native capture pilot','',f"Expected: {expected}; received: {len(results)}.",'',
          ' · '.join(f'{key}: {value}' for key,value in sorted(counts.items())), '',
          '| Package | Status | Ninja targets | Files |','| --- | --- | ---: | ---: |']
    rows += [f"| {r['package']} | {r['status']} | {r['capture'].get('ninja_targets',0)} | {r['capture'].get('files',0)} |" for r in results]
    rows+=['','Declared tags are not semantic coverage. Build/test/Pinned: NOT_RUN.']
    text='\n'.join(rows)+'\n'; (output/'summary.md').write_text(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'],'a') as f: f.write(text)
    return 0 if len(results)==expected and counts['CAPTURED']==expected else 1


def main():
    p=argparse.ArgumentParser(description=__doc__); sub=p.add_subparsers(dest='action',required=True)
    plan=sub.add_parser('plan'); plan.add_argument('--only',default='')
    run=sub.add_parser('run'); run.add_argument('package'); run.add_argument('toolchain',type=Path); run.add_argument('work',type=Path); run.add_argument('output',type=Path); run.add_argument('--local',dest='local_only',action='store_true'); run.add_argument('--timeout',type=int,default=600)
    summ=sub.add_parser('summarize'); summ.add_argument('root',type=Path); summ.add_argument('--expected',type=int,required=True); summ.add_argument('--output',type=Path,required=True)
    verify=sub.add_parser('verify'); verify.add_argument('root',type=Path); verify.add_argument('--sha256'); verify.add_argument('--public',action='store_true')
    args=p.parse_args()
    if args.action=='plan':
        names=[e['name'] for e in catalog()['packages']]
        selection=args.only or (ROOT/'corpus/selection.txt').read_text().strip()
        if selection!='all':
            if selection not in names: raise ValueError('unknown-package')
            names=[selection]
        print(json.dumps(names)); return 0
    if args.action=='verify':
        print(json.dumps(verify_capture(args.root,args.sha256,args.public))); return 0
    if args.action=='run': return capture(args.package,args.toolchain,args.work,args.output,args.local_only,args.timeout)
    return summarize(args.root,args.expected,args.output)

if __name__=='__main__': raise SystemExit(main())
