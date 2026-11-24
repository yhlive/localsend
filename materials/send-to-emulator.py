#!/usr/bin/env python3
"""Send workshop files to a LocalSend Android emulator via an adb forward."""

import argparse
import hashlib
import json
import mimetypes
from pathlib import Path
import ssl
import subprocess
import sys
import time
from tempfile import TemporaryDirectory
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4

def post(url, payload, content_type, context):
    request = Request(url, data=payload, headers={'Content-Type': content_type})
    with urlopen(request, context=context, timeout=120) as response:
        return response.status, response.read()

def tls_sender():
    context = ssl._create_unverified_context()
    with TemporaryDirectory() as work:
        cert = Path(work) / 'workshop-cert.pem'
        key = Path(work) / 'workshop-key.pem'
        config = Path(work) / 'openssl.cnf'
        config.write_text(
            '[req]\ndistinguished_name=dn\nx509_extensions=device\nprompt=no\n'
            '[dn]\nCN=LocalSend Workshop\n'
            '[device]\nbasicConstraints=critical,CA:FALSE\n'
            'keyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n'
        )
        result = subprocess.run(
            ['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
             '-keyout', str(key), '-out', str(cert), '-days', '1',
             '-config', str(config), '-sha256'],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        if result.returncode != 0:
            raise OSError(f'Could not create the test client certificate: {result.stderr.strip()}')
        context.load_cert_chain(str(cert), str(key))
        der = ssl.PEM_cert_to_DER_cert(cert.read_text())
    return context, hashlib.sha256(der).hexdigest().upper()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=55317)
    parser.add_argument('--alias', default='Northline Dispatch')
    parser.add_argument('--http', action='store_true', help='Use when the emulator has encryption disabled.')
    parser.add_argument('files', type=Path, nargs='+')
    args = parser.parse_args()

    protocol = 'http' if args.http else 'https'
    base = f'{protocol}://127.0.0.1:{args.port}/api/localsend/v2'
    # The forwarded emulator endpoint presents its own LocalSend certificate.
    context, fingerprint = tls_sender() if protocol == 'https' else (None, str(uuid4()))
    file_bodies = {}
    metadata = {}
    for path in args.files:
        file_id = str(uuid4())
        content = path.read_bytes()
        file_bodies[file_id] = content
        metadata[file_id] = {
            'id': file_id,
            'fileName': path.name,
            'size': len(content),
            'fileType': mimetypes.guess_type(path)[0] or 'application/octet-stream',
            'sha256': hashlib.sha256(content).hexdigest(),
        }
    payload = {
        'info': {
            'alias': args.alias,
            'version': '2.0',
            'deviceModel': 'Workshop Mac',
            'deviceType': 'desktop',
            'fingerprint': fingerprint,
            'port': 53317,
            'protocol': protocol,
            'download': False,
        },
        'files': metadata,
    }
    if context is not None:
        time.sleep(3)  # Allow for a small host/emulator clock offset.
    print('Waiting for Accept in LocalSend on the emulator...', flush=True)
    status, body = post(f'{base}/prepare-upload', json.dumps(payload).encode(), 'application/json', context)
    if status == 204:
        print('The receiver requested no uploads.')
        return
    session = json.loads(body)
    for index, (file_id, token) in enumerate(session['files'].items()):
        if index:
            time.sleep(1)  # Give the receiver time to persist each demo receipt.
        params = urlencode({'sessionId': session['sessionId'], 'fileId': file_id, 'token': token})
        post(f'{base}/upload?{params}', file_bodies[file_id], 'application/octet-stream', context)
        print(f"Sent {metadata[file_id]['fileName']}")

if __name__ == '__main__':
    try:
        main()
    except (URLError, OSError, ValueError, KeyError) as error:
        print(f'Transfer failed: {error}', file=sys.stderr)
        sys.exit(1)
