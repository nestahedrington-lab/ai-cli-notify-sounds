# Security Policy

## Reporting a Vulnerability

If you find a security issue, open a private GitHub security advisory if the
repository has advisories enabled. Otherwise, contact the maintainer privately
before publishing exploit details.

## Local Config Changes

The installer modifies local user configuration files for Codex, Claude Code,
and OpenCode. It creates timestamped backups before writing changes:

- `~/.codex/config.toml`
- `~/.claude/settings.json`
- `~/.config/opencode/opencode.json`

Review `install.sh` before running remote install commands.

