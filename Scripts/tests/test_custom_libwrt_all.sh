#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

root = Path(sys.argv[1])
path = root / '.github/workflows/CUSTOM-LIBWRT-ALL.yml'
assert path.is_file(), 'Missing LibWrt batch workflow'
workflow = path.read_text()
readme = (root / 'README.md').read_text()
template = (root / '.github/workflows/CUSTOM-iwrt-all.yml').read_text()
core = (root / '.github/workflows/CORE-ALL.yml').read_text()

def jobs(text):
    result = {}
    for name, block in re.findall(r'^  ([a-z0-9_]+):\n(.*?)(?=^  [a-z0-9_]+:|\Z)', text.split('\njobs:\n', 1)[1], re.M | re.S):
        values = dict(re.findall(r'^      ([A-Z_]+): (.*)$', block, re.M))
        result[name] = (block, values)
    return result

expected = jobs(template)
actual = jobs(workflow)
assert set(actual) == set(expected) and len(actual) == 4, 'LibWrt must preserve all four device jobs'
for name, (block, values) in actual.items():
    assert 'uses: ./.github/workflows/CORE-ALL.yml' in block
    assert 'secrets: inherit' in block
    assert values['SOURCE_TYPE'] == "'libwrt'"
    assert values['WRT_REPO_URL'] == 'https://github.com/LiBwrt/LibWrt'
    assert values['WRT_REPO_BRANCH'] == '25.12-nss'
    assert values['WRT_PACKAGE_MANAGER'] == 'apk'
    assert values['WRT_FIREWALL'] == 'fw4'
    for key, value in expected[name][1].items():
        if key not in ('SOURCE_TYPE', 'WRT_FIREWALL'):
            assert values[key] == value, f'{name}: template setting changed: {key}'

hash_input = workflow.split('      WRT_SOURCE_HASH_INFO:', 1)[1].split('\n#CI', 1)[0]
assert re.search(r"^        default: ''\s*$", hash_input, re.M), 'Do not inherit another repository commit'
assert 'name: CUSTOM-LIBWRT-ALL' in workflow
assert 'run-name: CUSTOM-LIBWRT-ALL-' in workflow
assert '`25.12-nss`' in readme and 'main-nss' not in readme, 'README must document the live LibWrt branch'

# 从真实工作流提取源码选择代码，验证显式 LibWrt 仓库不会被设备回退逻辑覆盖。
source_selection = core.split('        # 源码仓库：', 1)[1].split('        echo "WRT_REPO_URL=', 1)[0]
source_selection = '\n'.join(line[8:] for line in source_selection.splitlines()[1:])
for device in ('cmiot-ax18-nowifi', 'jd-ax6600-wifi', 'gl-mt6000-wifi', 'gl-mt6000-nowifi'):
    output = subprocess.check_output(['bash', '-c', source_selection + '\nprintf "%s\\n" "$WRT_REPO_URL" "$WRT_REPO_BRANCH"'], env={
        'PATH': '/usr/bin:/bin', 'WRT_DEVICE': device, 'SOURCE_TYPE': 'libwrt',
        'WRT_REPO_URL': 'https://github.com/LiBwrt/LibWrt', 'WRT_REPO_BRANCH': '25.12-nss',
    }, text=True)
    assert output.splitlines()[-2:] == ['https://github.com/LiBwrt/LibWrt', '25.12-nss']

env_block = core.split('\nenv:\n', 1)[1].split('\n#CI权限', 1)[0]
assert 'WRT_REPO_URL: ${{ inputs.WRT_REPO_URL }}' in env_block, 'Reusable workflow must pass repository input to shell'
assert 'WRT_REPO_BRANCH: ${{ inputs.WRT_REPO_BRANCH }}' in env_block, 'Reusable workflow must pass branch input to shell'
print('test_custom_libwrt_all: ok')
PY
