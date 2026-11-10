#!/usr/bin/env python3
"""Reject private local paths, credentials and personal metadata before upload."""
import argparse
import ipaddress
import re
import subprocess
from pathlib import Path

BOT_NAME = 'Native Corpus Bot'
BOT_EMAIL = 'native-corpus-bot@users.noreply.github.com'
SECRET = re.compile(r'github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----|https?://[^/\s:]+:[^@\s]+@')
HOME_PATH = re.compile(r'/(?:home|Users)/[A-Za-z0-9._-]+')
PRIVATE_ROOT = re.compile(r'(?<![\w/])/(?:work|root|private)/[A-Za-z0-9]')
EMAIL = re.compile(r'[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
IPV4 = re.compile(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])')
INTERNAL_HOST = re.compile(r'\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:internal|local|lan|corp)\b')


# Four-component CMake/package versions can look like IPv4. Accept only these
# explicit version contexts; the same numeric text in addresses remains denied.
_VERSION = r'(?P<version>[0-9]+(?:\.[0-9]+){3})'
VERSION_CONTEXTS = [
    re.compile(r'(?:\b|-D)VERSION=(?:\\*")'+_VERSION+r'(?:\\*")'),
    re.compile(r'(?<![\w-])protoc-'+_VERSION+r'(?![0-9.])'),
    re.compile(r'^CMAKE_PROJECT_VERSION:STATIC='+_VERSION+r'\s*$',re.MULTILINE),
    re.compile(r'"name"\s*:\s*"CMAKE_PROJECT_VERSION"\s*,\s*"properties"\s*:\s*\[\s*\{\s*"name"\s*:\s*"HELPSTRING"\s*,\s*"value"\s*:\s*"Value Computed by CMake"\s*\}\s*\]\s*,\s*"type"\s*:\s*"STATIC"\s*,\s*"value"\s*:\s*"'+_VERSION+r'"'),
]


def problems(data, legal_notice=False):
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return ['non-text']
    found = []
    if '\0' in text: found.append('nul-byte')
    if SECRET.search(text): found.append('credential-pattern')
    if any(m.group() != '/home/runner' for m in HOME_PATH.finditer(text)):
        found.append('personal-home-path')
    if PRIVATE_ROOT.search(text): found.append('private-work-path')
    if INTERNAL_HOST.search(text): found.append('internal-hostname')
    if not legal_notice and any(m.group() != BOT_EMAIL for m in EMAIL.finditer(text)):
        found.append('personal-email')
    versions=[match.span('version') for pattern in VERSION_CONTEXTS for match in pattern.finditer(text)]
    for match in IPV4.finditer(text):
        if any(start<=match.start() and match.end()<=end for start,end in versions):continue
        try:
            ipaddress.IPv4Address(match.group())
        except ipaddress.AddressValueError:
            continue
        found.append('ip-address'); break
    # Full IPv6 literals, with optional brackets; C++ scope tokens are ignored.
    for token in re.findall(r'(?<![\w:@.-])\[?[0-9a-fA-F]*:[0-9a-fA-F:]+\]?(?![\w:@.-])', text):
        try:
            ipaddress.IPv6Address(token.strip('[]'))
        except ipaddress.AddressValueError:
            continue
        found.append('ip-address'); break
    return sorted(set(found))


def scan(root):
    root = Path(root)
    if not root.is_dir() or root.is_symlink() or root.resolve() != root.absolute():
        raise ValueError('unsafe publication root')
    count = total = 0
    findings = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            findings.append({'file':str(path.relative_to(root)), 'reasons':['symlink']}); continue
        if path.is_dir(): continue
        if not path.is_file(): raise ValueError('non-regular publication input')
        count += 1; total += path.stat().st_size
        if count > 10000 or total > 128*1024*1024:
            raise ValueError('publication size limit')
        rel = path.relative_to(root).as_posix()
        reasons = problems(path.read_bytes(), '/licenses/upstream/' in '/'+rel)
        if reasons: findings.append({'file':rel, 'reasons':reasons})
    return {'files':count,'bytes':total,'findings':findings}


def commit_identity(repo, revision):
    data = subprocess.check_output(['git','show','-s','--format=%an%n%ae%n%cn%n%ce%n%B',revision],cwd=repo,text=True).splitlines()
    return data[:4] == [BOT_NAME,BOT_EMAIL,BOT_NAME,BOT_EMAIL] and not problems('\n'.join(data[4:]).encode())


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    args=parser.parse_args()
    result=scan(args.root)
    # Do not print matched private values, only file names and reason codes.
    import json
    print(json.dumps(result))
    return bool(result['findings'])

if __name__=='__main__': raise SystemExit(main())
