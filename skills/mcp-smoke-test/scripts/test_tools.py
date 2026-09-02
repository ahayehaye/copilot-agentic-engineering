#!/usr/bin/env python
"""Smoke-test an MCP server's tools via stdio JSON-RPC transport.

Usage:
    python test_tools.py <server-name>

Connects to the installed server under ~/.agents/mcp/<server-name>/server.py
using the venv at ~/.agents/mcp/.venv, calls each registered tool,
and verifies the response.
"""

import json
import os
import subprocess
import sys
import time

VENV_DIR = os.path.expanduser("~/.agents/mcp/.venv")
SERVERS_DIR = os.path.expanduser("~/.agents/mcp")


def get_venv_python():
    """Detect the venv's Python executable (bin/ on Unix, Scripts/ on Windows)."""
    for subdir in ("bin", "Scripts"):
        for exe in ("python", "python.exe"):
            path = os.path.join(VENV_DIR, subdir, exe)
            if os.path.isfile(path):
                return path
    return "python"

REQUEST_ID = 1


def next_id():
    global REQUEST_ID
    REQUEST_ID += 1
    return REQUEST_ID - 1


def send_message(proc, message):
    """Send a JSON-RPC message to the server subprocess."""
    payload = json.dumps(message) + "\n"
    proc.stdin.write(payload)
    proc.stdin.flush()


def read_response(proc, timeout=10):
    """Read a single JSON-RPC response line from the server subprocess."""
    deadline = time.monotonic() + timeout
    buf = ""
    while time.monotonic() < deadline:
        try:
            chunk = proc.stdout.readline()
            if not chunk:
                # EOF — server exited
                return None
            buf += chunk
            if buf.endswith("\n"):
                return json.loads(buf.strip())
        except (json.JSONDecodeError, ValueError):
            return None
    return None


def run_initialize(proc):
    """Send initialize request and return the response."""
    rid = next_id()
    send_message(proc, {
        "jsonrpc": "2.0",
        "id": rid,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "smoke-test-client", "version": "0.1.0"},
        },
    })
    return read_response(proc)


def send_initialized(proc):
    """Send the initialized notification."""
    send_message(proc, {
        "jsonrpc": "2.0",
        "method": "notifications/initialized",
    })
    # Notifications have no response; give the server a moment
    time.sleep(0.1)


def call_tool(proc, tool_name, arguments):
    """Call a tool and return the response."""
    rid = next_id()
    send_message(proc, {
        "jsonrpc": "2.0",
        "id": rid,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments,
        },
    })
    return read_response(proc)


def main():
    if len(sys.argv) < 2:
        print("Usage: python test_tools.py <server-name>")
        sys.exit(1)

    server_name = sys.argv[1]
    server_script = os.path.join(SERVERS_DIR, server_name, "server.py")
    venv_python = get_venv_python()

    # --- Pre-flight checks ---
    failures = 0

    if not os.path.isfile(venv_python):
        print(f"FAIL: venv python not found at {venv_python}")
        sys.exit(1)

    if not os.path.isfile(server_script):
        print(f"FAIL: server script not found at {server_script}")
        sys.exit(1)

    print(f"Testing server: {server_name}")
    print(f"  venv python : {venv_python}")
    print(f"  server path : {server_script}")
    print()

    # --- Launch server subprocess ---
    try:
        proc = subprocess.Popen(
            [venv_python, server_script],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,  # line-buffered
        )
    except FileNotFoundError:
        print(f"FAIL: cannot launch server — {venv_python} not executable")
        sys.exit(1)

    def cleanup():
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()

    try:
        # --- Step 1: initialize ---
        print("[1/5] Sending initialize request ...")
        resp = run_initialize(proc)
        if resp is None:
            print("  FAIL: no response to initialize")
            failures += 1
        elif "error" in resp:
            print(f"  FAIL: initialize error: {resp['error']}")
            failures += 1
        else:
            capabilities = resp.get("result", {}).get("capabilities", {})
            tools_cap = capabilities.get("tools")
            if tools_cap is not None:
                print(f"  PASS: server initialized (has tools capability)")
            else:
                print(f"  PASS: server initialized")

        # --- Step 2: initialized notification ---
        print("[2/5] Sending initialized notification ...")
        send_initialized(proc)
        print("  PASS: notification sent")

        # --- Step 3: test echo tool ---
        echo_message = "smoke-test-ping-12345"
        print(f"[3/5] Calling echo('{echo_message}') ...")
        resp = call_tool(proc, "echo", {"message": echo_message})
        if resp is None:
            print("  FAIL: no response from echo")
            failures += 1
        elif "error" in resp:
            print(f"  FAIL: echo error: {resp['error']}")
            failures += 1
        else:
            content = resp.get("result", {}).get("content", [])
            text = content[0].get("text", "") if content else ""
            if text == echo_message:
                print(f"  PASS: echo returned '{text}' (matches input)")
            else:
                print(f"  FAIL: echo returned '{text}' (expected '{echo_message}')")
                failures += 1

        # --- Step 4: test greet tool ---
        greet_name = "SmokeTester"
        expected_greeting = f"Hello, {greet_name}!"
        print(f"[4/5] Calling greet('{greet_name}') ...")
        resp = call_tool(proc, "greet", {"name": greet_name})
        if resp is None:
            print("  FAIL: no response from greet")
            failures += 1
        elif "error" in resp:
            print(f"  FAIL: greet error: {resp['error']}")
            failures += 1
        else:
            content = resp.get("result", {}).get("content", [])
            text = content[0].get("text", "") if content else ""
            if expected_greeting in text:
                print(f"  PASS: greet returned '{text}' (contains '{expected_greeting}')")
            else:
                print(f"  FAIL: greet returned '{text}' (expected to contain '{expected_greeting}')")
                failures += 1

        # --- Step 5: list tools ---
        print("[5/5] Listing available tools ...")
        rid = next_id()
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": rid,
            "method": "tools/list",
            "params": {},
        })
        resp = read_response(proc)
        if resp and "result" in resp:
            tools = resp["result"].get("tools", [])
            names = [t.get("name", "?") for t in tools]
            print(f"  PASS: server advertises tools: {names}")
        else:
            print(f"  WARN: could not list tools (server may not support tools/list)")

    finally:
        cleanup()

    # --- Summary ---
    print()
    if failures == 0:
        print(f"PASS: All tool tests passed for '{server_name}'")
        sys.exit(0)
    else:
        print(f"FAIL: {failures} test(s) failed for '{server_name}'")
        sys.exit(1)


if __name__ == "__main__":
    main()
