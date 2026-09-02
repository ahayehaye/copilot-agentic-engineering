---
name: mcp-smoke-test
description: "Smoke-test an MCP server: install, verify registration, exercise tools, and clean up"
version: 0.1.0
---

# MCP Smoke Test

Verify that an MCP server installs correctly, registers in the Copilot configuration, and responds to tool calls — then clean up.

This skill is generic. Replace `<server-name>` with the name of any MCP server under `mcp-servers/`.

## Procedure

### 1. Install the server

```bash
scripts/mcp-manager.sh install <server-name>
```

**Expected output:**

```
→ Installing <server-name> <version>
  Created virtualenv at ~/.agents/mcp/.venv
  Updated ~/.copilot/mcp-config.json with '<server-name>'
```

**Pass:** Exit code `0`, version printed, no errors.
**Fail:** Non-zero exit, missing virtualenv, or error messages.

### 2. Verify registration

Confirm that `~/.copilot/mcp-config.json` contains a `<server-name>` entry:

```bash
python -c "
import json, sys
with open('$HOME/.copilot/mcp-config.json') as f:
    config = json.load(f)

server = '<server-name>'
entry = config.get(server)
if not entry:
    print(f'FAIL: {server} not found in mcp-config.json')
    sys.exit(1)

checks = {
    'command':  entry.get('command'),
    'args':     entry.get('args'),
    'transport': entry.get('transport') == 'stdio',
    'tools':    entry.get('tools') == ['*'],
}

all_pass = True
for key, ok in checks.items():
    status = 'PASS' if ok else 'FAIL'
    print(f'  [{status}] {key}: {ok}')
    if not ok:
        all_pass = False

if all_pass:
    print(f'PASS: {server} registration verified')
else:
    print(f'FAIL: {server} registration incomplete')
    sys.exit(1)
"
```

**Expected output:**

```
  [PASS] command: /path/to/venv/bin/python
  [PASS] args: ['/path/to/server/script.py']
  [PASS] transport: True
  [PASS] tools: True
PASS: <server-name> registration verified
```

**Pass:** All four fields present and correct.
**Fail:** Missing key, wrong transport type, or tools not set to `['*']`.

### 3. Test tools

Run the smoke-test client against the installed server:

```bash
python skills/mcp-smoke-test/scripts/test_tools.py <server-name>
```

The script launches the server via stdio, sends an MCP `initialize` handshake, and calls each tool:

- `echo` — verifies the response matches the input message exactly
- `greet` — verifies the response contains `Hello, {name}!`
- `tools/list` — confirms the server advertises its tools

**Expected output:**

```
Testing server: <server-name>
  venv python : ~/.agents/mcp/.venv/bin/python
  server path : ~/.agents/mcp/<server-name>/server.py

[1/5] Sending initialize request ...
  PASS: server initialized
[2/5] Sending initialized notification ...
  PASS: notification sent
[3/5] Calling echo('smoke-test-ping-12345') ...
  PASS: echo returned 'smoke-test-ping-12345' (matches input)
[4/5] Calling greet('SmokeTester') ...
  PASS: greet returned 'Hello, SmokeTester!' (contains 'Hello, SmokeTester!')
[5/5] Listing available tools ...
  PASS: server advertises tools: ['echo', 'greet']

PASS: All tool tests passed for '<server-name>'
```

**Pass:** Exit code `0`, all steps show `PASS`.
**Fail:** Non-zero exit, missing responses, or unexpected tool output.

### 4. Cleanup

Uninstall the server to ensure idempotency:

```bash
scripts/mcp-manager.sh uninstall <server-name>
```

**Expected output:**

```
✓ <server-name> <version> uninstalled
```

Verify the entry is removed from `~/.copilot/mcp-config.json`:

```bash
python -c "
import json, sys
with open('$HOME/.copilot/mcp-config.json') as f:
    config = json.load(f)
if '<server-name>' in config:
    print('FAIL: <server-name> still in mcp-config.json after uninstall')
    sys.exit(1)
print('PASS: <server-name> removed from mcp-config.json')
"
```

**Pass:** Server directory deleted and config entry removed.
**Fail:** Residual files or stale config entry.

## Example — sample-server

```bash
scripts/mcp-manager.sh install sample-server
# Verify registration (replace <server-name> with sample-server)
python skills/mcp-smoke-test/scripts/test_tools.py sample-server
scripts/mcp-manager.sh uninstall sample-server
```
