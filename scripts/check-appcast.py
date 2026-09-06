#!/usr/bin/env python3
"""Verify release metadata and both Ed25519 signatures using the embedded public key."""
import os
import plistlib
import re
import subprocess
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
feed, archive, notes, version = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
item = ET.parse(feed).find('./channel/item')
assert item is not None, 'Missing update entry'
if os.environ.get('UNIVERSAL') == '1':
    assert item.find('sparkle:hardwareRequirements', ns) is None, 'Universal feed restricts supported architectures'
assert item.findtext('sparkle:version', namespaces=ns) == version, 'Incorrect update version'
enclosure = item.find('enclosure')
assert enclosure is not None, 'Missing update archive'
assert enclosure.get('url') == f'https://github.com/0x63616c/copy-cat/releases/download/v{version}/CopyCat-macOS.zip', 'Unexpected archive URL'
release_notes = item.find('sparkle:releaseNotesLink', ns)
assert release_notes is not None and release_notes.text == f'https://github.com/0x63616c/copy-cat/releases/download/v{version}/CopyCat-macOS.md', 'Unexpected release notes URL'
assert item.findtext('sparkle:fullReleaseNotesLink', namespaces=ns) == f'https://github.com/0x63616c/copy-cat/blob/v{version}/CHANGELOG.md', 'Unexpected full release notes URL'
notes_signature = release_notes.get('{'+ns['sparkle']+'}edSignature')
notes_length = release_notes.get('{'+ns['sparkle']+'}length')
assert notes_signature and notes_length and int(notes_length) == notes.stat().st_size, 'Unsigned or incorrect release notes'
assert int(enclosure.get('length', '0')) == archive.stat().st_size, 'Incorrect archive size'
archive_signature = enclosure.get('{'+ns['sparkle']+'}edSignature')
assert archive_signature, 'Unsigned update archive'
with zipfile.ZipFile(archive) as package:
    info = plistlib.loads(package.read('CopyCat.app/Contents/Info.plist'))
expected_key = plistlib.loads((root / 'Resources/Info.plist.template').read_bytes())['SUPublicEDKey']
assert info['SUPublicEDKey'] == expected_key, 'Archive has an unexpected public key'
assert info['CFBundleVersion'] == version, 'Archive version differs from feed'
assert info['SURequireSignedFeed'] and info['SUVerifyUpdateBeforeExtraction'], 'Update validation disabled'
raw = feed.read_bytes()
footer = re.search(rb'<!-- sparkle-signatures:\s*edSignature: ([A-Za-z0-9+/=]+)\s*length: ([0-9]+)\s*-->\s*$', raw)
assert footer, 'Missing feed signature block'
assert int(footer[2]) == footer.start(), 'Feed contains unsigned bytes before its signature'
verifier = ['swift', str(root / 'scripts/verify-signature.swift')]
subprocess.run(verifier + [str(feed), footer[1].decode(), expected_key, footer[2].decode()], check=True)
subprocess.run(verifier + [str(archive), archive_signature, expected_key], check=True)
subprocess.run(verifier + [str(notes), notes_signature, expected_key], check=True)
print(f'Update feed OK: {version}, {archive.stat().st_size:,} bytes, signed release notes')
