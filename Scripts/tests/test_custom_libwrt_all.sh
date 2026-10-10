#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

root = Path(sys.argv[1])
workflow_path = root / '.github/workflows/CUSTOM-iwrt-all.yml'
workflow = workflow_path.read_text()
readme = (root / 'README.md').read_text()
core = (root / '.github/workflows/CORE-ALL.yml').read_text()
legacy_path = root / '.github/workflows/CUSTOM-LIBWRT-ALL.yml'

assert not legacy_path.exists(), 'LibWrt batch workflow should be merged into CUSTOM-iwrt-all.yml'
assert 'name: CUSTOM-IWRT-ALL' in workflow
assert 'SOURCE_TYPE:' in workflow
source_block = workflow.split('      SOURCE_TYPE:', 1)[1].split('      WRT_FIREWALL:', 1)[0]
assert re.search(r"^        type: choice\s*$", source_block, re.M)
assert re.search(r"^          - vwrt\s*$", source_block, re.M)
assert re.search(r"^          - libwrt\s*$", source_block, re.M)
assert re.search(r"^        default: 'vwrt'\s*$", source_block, re.M)

hash_block = workflow.split('      WRT_SOURCE_HASH_INFO:', 1)[1].split('\n#CI', 1)[0]
assert re.search(r"^        default: ''\s*$", hash_block, re.M), 'source HASH must follow the selected branch by default'

jobs = {}
jobs_text = workflow.split('\njobs:\n', 1)[1]
for name, block in re.findall(r'^  ([a-z0-9_]+):\n(.*?)(?=^  [a-z0-9_]+:|\Z)', jobs_text, re.M | re.S):
    if 'uses: ./.github/workflows/CORE-ALL.yml' in block:
        jobs[name] = block
assert len(jobs) == 4, 'merged workflow must preserve all four device jobs'
for name, block in jobs.items():
    assert 'uses: ./.github/workflows/CORE-ALL.yml' in block
    assert 'secrets: inherit' in block
    assert 'SOURCE_TYPE: ${{ inputs.SOURCE_TYPE }}' in block, f'{name}: source type must be selected externally'
    assert "WRT_PACKAGE_MANAGER: ${{ inputs.SOURCE_TYPE == 'libwrt' && 'apk' || 'auto' }}" in block, f'{name}: libwrt must use apk'
    assert 'WRT_REPO_URL:' not in block
    assert 'WRT_REPO_BRANCH:' not in block

assert 'CUSTOM-LIBWRT-ALL' not in readme
assert 'CUSTOM-IWRT-ALL' in readme and 'SOURCE_TYPE' in readme
assert 'WRT_REPO_URL="https://github.com/LiBwrt/LibWrt"' in core
assert 'WRT_REPO_BRANCH="25.12-nss"' in core

source_selection = core.split('        # 源码仓库：', 1)[1].split('        echo "WRT_REPO_URL=', 1)[0]
source_selection = '\n'.join(line[8:] for line in source_selection.splitlines()[1:])
cases = [
    ('libwrt', 'cmiot-ax18-nowifi', 'https://github.com/LiBwrt/LibWrt', '25.12-nss'),
    ('libwrt', 'jd-ax6600-wifi', 'https://github.com/LiBwrt/LibWrt', '25.12-nss'),
    ('libwrt', 'gl-mt6000-wifi', 'https://github.com/immortalwrt/immortalwrt', 'master'),
    ('libwrt', 'gl-mt6000-nowifi', 'https://github.com/immortalwrt/immortalwrt', 'master'),
    ('vwrt', 'cmiot-ax18-nowifi', 'https://github.com/VIKINGYFY/immortalwrt', 'main'),
    ('vwrt', 'gl-mt6000-wifi', 'https://github.com/immortalwrt/immortalwrt', 'master'),
    ('lean', 'gl-mt6000-nowifi', 'https://github.com/coolsnowwolf/lede', 'master'),
]
for source, device, repository, branch in cases:
    output = subprocess.check_output(
        ['bash', '-c', source_selection + '\nprintf "%s\\n" "$WRT_REPO_URL" "$WRT_REPO_BRANCH"'],
        env={
            'PATH': '/usr/bin:/bin',
            'WRT_DEVICE': device,
            'SOURCE_TYPE': source,
            'WRT_REPO_URL': '',
            'WRT_REPO_BRANCH': '',
        },
        text=True,
    )
    assert output.splitlines()[-2:] == [repository, branch], f'{source}/{device}: unexpected repository or branch'

output = subprocess.check_output(
    ['bash', '-c', source_selection + '\nprintf "%s\\n" "$WRT_REPO_URL" "$WRT_REPO_BRANCH"'],
    env={
        'PATH': '/usr/bin:/bin', 'WRT_DEVICE': 'gl-mt6000-nowifi', 'SOURCE_TYPE': 'libwrt',
        'WRT_REPO_URL': 'https://example.com/custom.git', 'WRT_REPO_BRANCH': 'custom',
    }, text=True,
)
assert output.splitlines()[-2:] == ['https://example.com/custom.git', 'custom'], 'explicit repository must take priority'
print('test_custom_libwrt_all: ok')
PY
