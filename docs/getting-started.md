# Getting Started

This guide walks you through setting up the development environment and running the project's scripts.

## Prerequisites

- **Python 3.11+**
- **Poetry** — manages tooling dependencies

## Installing Poetry

You can install Poetry using one of these methods:

### Option 1: Install via pipx (recommended)

```bash
pip install pipx
pipx ensurepath
pipx install poetry
```

### Option 2: Install via get-poetry.py

```bash
curl -sSL https://install.python-poetry.org | python -
```

### Verify the installation

```bash
poetry --version
```

## Setting Up the Project

Install project dependencies with Poetry:

```bash
poetry install
```

This installs tooling dependencies into Poetry's virtual environment.

## Running the Smoke Test

The smoke test verifies that an MCP server is correctly installed, configured, and functional. It uses the shared virtual environment (`~/.agents/mcp/.venv`) — run it directly with `python`:

```bash
python skills/mcp-smoke-test/scripts/test_tools.py sample-server
```

The smoke test runs through a complete validation flow:

1. **Install** — Ensures the MCP server is installed in the shared venv.
2. **Verify config** — Checks that the server appears in the MCP configuration.
3. **Test tools** — Executes each available tool to confirm the server responds correctly.
4. **Cleanup** — Shuts down the server process and reports results.

To run the smoke test against a different server, replace `sample-server` with the server name from your MCP configuration.
