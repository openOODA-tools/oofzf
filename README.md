# oofzf

> **Sovereign interactive fuzzy finder and candidate ranker for the openOODA era.**  
> *A drop-in `fzf` alternative written in pure openOODA, featuring negative-trust capability security, ANSI scoring, `oote` theme integration, preview panes, and a first-class Model Context Protocol (MCP) surface.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Installation

`oofzf` has zero runtime dependencies. It compiles to a standalone native binary linked directly with libc.

### Universal Web Installer
Installs the standalone native binary to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://openooda-tools.github.io/oofzf/install.sh | bash
```

### Debian / Ubuntu (APT)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oofzf/install.sh | bash -s -- --apt

# Or manual package install
sudo dpkg -i oofzf_0.2.0-1_amd64.deb
```

### Fedora / RHEL / CentOS (DNF)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oofzf/install.sh | bash -s -- --dnf

# Or manual RPM install
sudo dnf install ./oofzf-0.2.0-1.fc44.x86_64.rpm
```

### Arch Linux (PKGBUILD)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oofzf/install.sh | bash -s -- --arch

# Or manual build via packaging/PKGBUILD
cd packaging && makepkg -si
```

### Clean Uninstaller
To cleanly remove `oofzf` and any installed package manager entries:

```bash
# Automated via standalone uninstaller
curl -fsSL https://openooda-tools.github.io/oofzf/uninstall.sh | bash

# Or via installer flag
curl -fsSL https://openooda-tools.github.io/oofzf/install.sh | bash -s -- --uninstall

# Or preview removal without making changes (dry-run)
curl -fsSL https://openooda-tools.github.io/oofzf/uninstall.sh | bash -s -- --dry-run
```

---

## 2. Usage & Features

### Interactive Filtering & Selection
Pass candidates over stdin or point to a file:

```bash
# Search files from oofind
oofind . | oofzf

# Pre-fill a search query
ls -1 | oofzf -q "main"

# Non-interactive filter mode (sorted output to stdout)
printf "apple\nbanana\ncherry\napricot\n" | oofzf -f "ap"

# Fast single-selection or exit-on-zero mode
oofzf -f "apple" -1
oofzf -f "missing" -0

# Disable color escapes
oofzf --no-color -f "ap"
```

### Theme Palettes (`oote` Integration)
`oofzf` detects and applies active themes from `~/.openooda/theme.oot` or `$OODA_THEME`:

```bash
# Override active theme on invocation
oofzf -t 1982
oofzf --theme=cyberpunk
oofzf --theme=dracula
```

### Model Context Protocol (MCP) Mode
`oofzf` speaks JSON-RPC 2.0 MCP over stdio for LLM coding agents:

```bash
oofzf --mcp
```

#### MCP Tools Provided:
- `fuzzy_match`: Score a candidate string against a query with match positions.
  - Parameters: `query` (string, required), `candidate` (string, required).
  - Returns: `{"matched": bool, "score": int, "positions": int[]}`.
- `rank_candidates`: Rank newline-delimited or JSON array items by match score.
  - Parameters: `query` (string, required), `items` (string|string[], required), `limit` (int, optional), `threshold` (int, optional).
- `filter_candidates`: Filter candidate lines matching query with optional invert.
  - Parameters: `query` (string, required), `items` (string, required), `invert` (bool, optional).
- `highlight_match`: Style matched characters in candidate using ANSI escapes.
  - Parameters: `query` (string, required), `candidate` (string, required), `theme` (string, optional).

---

## 3. Capability Security & Verification

`oofzf` enforces strict Object Capability Discipline (OCap):
- **FsReadCap**: Strictly bounded read-only access to files and stdin streams.
- **ProcessCap**: Bounded exit code handling.
- **Zero Ambient Authority**: Zero network sockets, zero child process spawning, zero unprompted disk writes.