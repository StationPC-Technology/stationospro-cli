# StationOS CLI

StationOS NAS command-line client for Linux, macOS, and Windows. This repository distributes installers and release binaries; source is maintained separately.

## Install

Linux / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/StationPC-Technology/stationospro-cli/main/install.sh | sh
```

Optionally install the bundled NAS skill for your AI client:

```bash
curl -fsSL https://raw.githubusercontent.com/StationPC-Technology/stationospro-cli/main/install.sh | sh -s -- --with-skill codex
```

Use `cursor`, `claude`, or `codex`. The default executable directory is `~/.local/bin`; add it to PATH if needed.

Windows PowerShell:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/StationPC-Technology/stationospro-cli/main/install.ps1 -OutFile install.ps1
.\install.ps1
```

For older releases, set `STATIONOS_CLI_VERSION=0.1.0` on Linux/macOS or pass `-Version 0.1.0` on Windows. Downloads are checked against the release's SHA-256 checksums.

## Connect to your NAS

Logging in opens your browser: sign in to your NAS account, pick the modules the CLI may access (files, photos, Docker, ...), and confirm. Tokens are stored in the OS keychain and refresh automatically.

```bash
stationos-cli auth login --server https://<NAS_ADDRESS>:9501
stationos-cli auth status
```

- `--server` is your NAS web address (HTTPS recommended; plain HTTP works on a trusted LAN only). Do not append `/mcp`.
- Optionally pre-select modules with `--scope` (comma-separated, e.g. `--scope file:ro,file:rw,docker`, or `--scope all`). The final scope is what you confirm on the web consent page.
- Plain-HTTP targets warn about on-network token visibility; prefer the HTTPS domain shown in the NAS web AI-access guide.

Log out from the terminal; this also revokes the device-side authorization:

```bash
stationos-cli auth logout
```

## Try it

```bash
stationos-cli file ls /                    # list your NAS home root
stationos-cli file search notes           # search file names
stationos-cli call docker.container.list  # call any authorized tool directly
stationos-cli schema docker.container.create  # inspect a tool's arguments
```

Destructive tools ask for confirmation before running (rerun with `--confirm`).

## Use it as an MCP bridge (Codex / Cherry Studio / any MCP client)

After `auth login`, expose your NAS through the stdio bridge — tokens never enter the AI client's config:

Cursor MCP configuration:

```json
{"mcpServers":{"stationos":{"command":"stationos-cli","args":["mcp"]}}}
```

Claude Code:

```bash
claude mcp add --transport stdio stationos -- stationos-cli mcp
```

Codex:

```bash
codex mcp add nas -- stationos-cli mcp
```

All bridge clients on this machine share one authorization; revoking it on the NAS web disconnects them all at once.

## Notes

- The CLI registers no tools of its own; the tool list comes live from your NAS, so new NAS capabilities work without upgrading the CLI.
- High-risk NAS operations may require a second confirmation on the NAS web page; the CLI will tell you when that happens.
- HTTP direct connections bypass the NAS certificate — use them only on a trusted LAN; prefer the HTTPS device domain.
