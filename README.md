# Project Context Manager

A comprehensive Claude Code plugin for managing large multi-language projects with secure credential storage, intelligent session resumption, phase-based project chunking, and seamless plan mode integration.

## Features

### 🔐 Secure Credential Management
- **System keychain integration** - Uses native OS keychains (macOS Keychain, Windows Credential Manager, Linux Secret Service)
- **Multiple credential types** - API keys, private keys (SSH/GPG), OAuth tokens, database credentials
- **Leak prevention** - Automatically scans commands, git commits, and file writes to prevent credential exposure
- **Per-project isolation** - Credentials are stored per project with secure encryption

### 📊 Intelligent Project Indexing
- **Polyglot support** - Automatic detection and analysis of multi-language codebases
- **Comprehensive indexing** - File structure, language breakdown, key files, dependencies
- **Auto-update** - Indexes update automatically on project switch and file changes
- **Dependency tracking** - Tracks package.json, Cargo.toml, requirements.txt, go.mod, etc.

### 🧩 Phase-Based Project Chunking
- **Semantic chunking** - Organizes projects by logical phases, not arbitrary line counts
- **Context-aware navigation** - Navigate between phases with full context loading
- **Syntax highlighting** - View chunk summaries with syntax highlighting
- **Dependency visualization** - See imports and dependencies for each chunk

### 💾 Session Management & Resumption
- **Automatic state tracking** - Tracks last edited files, chunk location, todos, plan context
- **Smart resume** - Shows session summary, auto-loads files, restores plan mode state
- **Session history** - Browse and resume from previous sessions
- **Cross-session continuity** - Seamless work continuation across sessions

### 📋 Plan Mode Integration
- **Auto-chunking** - Automatically chunks plans into phases
- **Progress tracking** - Tracks completion per phase/chunk
- **Plan generation** - Generates plans from project index
- **State restoration** - Restores plan mode context on resume

### 🎯 Ruthless Project Evaluation
- **Strict standards** - No participation trophies, production-ready or fail
- **Phase evaluation** - Assess individual phase completion against 8 mandatory criteria
- **Project evaluation** - Overall assessment of goals, architecture, and outcomes
- **Genius recommendations** - 9 categories of architectural improvements and optimizations
- **Real production patterns** - Recommendations based on actual QENEX HFT examples
- **Measurable outcomes** - All recommendations include before/after metrics

## Installation

### From Claude Code
```bash
# Install from marketplace (if published)
claude plugin install project-context-manager

# Or install from local directory
claude --plugin-dir /root/.claude/plugins/project-context-manager
```

### Manual Installation
```bash
# Copy plugin to Claude plugins directory
cp -r project-context-manager ~/.claude/plugins/

# Enable in Claude Code
claude plugin enable project-context-manager
```

## Prerequisites

### System Requirements
- **macOS**: Keychain Access (built-in)
- **Linux**: Secret Service API (`gnome-keyring` or `kwallet`)
- **Windows**: Windows Credential Manager (built-in)

### Optional Dependencies
- `git` - For repository analysis
- `ripgrep` (`rg`) - For fast file searching (fallback: `grep`)
- `python3` - For indexing scripts (usually pre-installed)

## Quick Start

### 1. Index Your Project
```bash
# Navigate to your project directory
cd /path/to/your/project

# Index the project
/index-project

# View project summary
/context-summary
```

### 2. Store Credentials Securely
```bash
# Store an API key
/store-credential --name "github-api" --type "api-key"

# Store SSH private key
/store-credential --name "deploy-key" --type "ssh-key" --file ~/.ssh/deploy_key

# Store database credentials
/store-credential --name "prod-db" --type "database" --username "admin"

# List stored credentials (names only, not values)
/list-credentials
```

### 3. Work with Chunks
```bash
# Create project chunks by phases
/chunk --create

# Navigate to a specific phase
/navigate --phase "authentication"

# View current chunk context
/chunk --current
```

### 4. Resume Work
```bash
# Resume from last session
/resume

# Resume from specific session
/resume --session "2024-01-20"

# Show session history
/resume --list
```

## Configuration

Create `.claude/project-context.local.md` in your project root:

```markdown
---
# Project Context Manager Configuration

# Active projects (automatically managed)
active_projects:
  - path: /home/user/project1
    last_session: 2024-01-22T10:30:00Z
    current_phase: "Phase 3: API Integration"
  - path: /home/user/project2
    last_session: 2024-01-21T15:45:00Z
    current_phase: "Phase 1: Setup"

# Chunking preferences
chunk_strategy: "phase-based"  # or "module-based", "file-based"
auto_chunk: true
chunk_context_lines: 50

# Indexing behavior
auto_index_on_switch: true
auto_index_on_changes: true
index_ignore_patterns:
  - "node_modules"
  - ".git"
  - "venv"
  - "__pycache__"
  - "dist"
  - "build"

# Security settings
credential_vault_path: ".claude/.credentials.enc"
leak_prevention_enabled: true
scan_git_commits: true
scan_bash_commands: true
scan_file_writes: true

# Session management
auto_resume_on_start: true
save_state_on_stop: true
max_session_history: 30

# Plan mode integration
auto_chunk_plans: true
track_plan_progress: true
generate_plans_from_index: true
---

# Notes
This file is git-ignored by default to protect project-specific settings.
```

## Commands

### Project Management
- `/index-project` - Scan and index current project
- `/context-summary` - Show project state, progress, and statistics
- `/evaluate` - Ruthless project/phase evaluation with genius recommendations

### Credential Management
- `/store-credential` - Securely store credentials (API keys, SSH keys, tokens, passwords)
- `/get-credential` - Retrieve stored credential (never logged)
- `/list-credentials` - List credential names (values hidden)

### Navigation
- `/chunk` - Create, view, or navigate project chunks
- `/navigate` - Navigate between project phases with context

### Session Management
- `/resume` - Resume from last session or specific session

## Security

### Credential Storage
- Credentials are stored in OS-native keychains
- Never stored in plain text
- Per-project isolation
- Encrypted at rest

### Leak Prevention
The plugin actively prevents credential leaks by:
- **Git commit scanning** - Blocks commits containing credentials
- **Command scanning** - Warns before executing commands with exposed secrets
- **File write detection** - Alerts when writing files with credential patterns
- **Log sanitization** - Credentials never appear in Claude Code logs

### Best Practices
1. **Never hardcode credentials** - Always use `/store-credential`
2. **Use descriptive names** - Name credentials clearly (e.g., "github-deploy-token")
3. **Rotate regularly** - Update stored credentials periodically
4. **Project-specific** - Store credentials per project, not globally
5. **Audit regularly** - Use `/list-credentials` to review stored secrets

## Architecture

### Components
- **4 Skills** - project-indexing, session-management, chunk-navigation, secure-credential-handling
- **9 Commands** - index-project, resume, chunk, navigate, context-summary, evaluate, store-credential, get-credential, list-credentials
- **3 Agents** - project-indexer (autonomous indexing), context-tracker (state management), project-evaluator (ruthless assessment)
- **3 Hooks** - SessionStart (restore context), Stop (save state), PreToolUse (leak prevention)

### Data Storage
```
.claude/
├── project-context.local.md      # Configuration (git-ignored)
├── .credentials.enc               # Encrypted credential vault (git-ignored)
├── .project-index.json            # Project structure index
├── .project-state.json            # Current session state (git-ignored)
├── .session-history.json          # Session history (git-ignored)
└── .chunks.json                   # Phase/chunk definitions
```

## Use Cases

### Polyglot Project Management
```bash
# Working on QENEX (Python/Rust/Go/Julia/Elixir/C++/Zig)
cd /home/ubuntu/qenex
/index-project

# Navigate to Rust modules
/navigate --phase "Rust High-Performance Services"

# Store API credentials
/store-credential --name "anthropic-api" --type "api-key"
```

### Long-Running Development
```bash
# Start work session
/index-project
/chunk --create

# Work on Phase 1...
# (Claude Code automatically tracks progress)

# End of day - state auto-saves on exit

# Next day - resume automatically
/resume
# Shows: "Resuming Phase 1: Authentication (60% complete)"
# Auto-loads: src/auth.py, tests/test_auth.py
```

### Multi-Project Workflow
```bash
# Project 1
cd /project1
/index-project
# Work...

# Switch to Project 2
cd /project2
/index-project  # Auto-saves project1 state, loads project2
# Work...

# Return to Project 1
cd /project1
/resume  # Automatically restores project1 context
```

### Ruthless Evaluation Workflow
```bash
# Phase completion check
/evaluate --phase "Phase 3: API Integration"
# Result: 85% complete
# Missing: Documentation incomplete (missing API examples)
# Missing: No error handling for rate limiting

# Overall project assessment
/evaluate --project
# Result: 78% complete
# Strengths: Solid architecture, good test coverage (92%)
# Weaknesses: Missing deployment automation, no monitoring setup
# Recommendation: Implement Prometheus + Grafana (see line 245 in ops/metrics.py)

# Quick health check
/evaluate --quick
# Shows: Tests passing, build succeeds, no TODOs in current files
```

## Troubleshooting

### Keychain Access Issues

**macOS:**
```bash
# Verify Keychain Access permissions
security find-generic-password -a "claude-code" -s "project-context"
```

**Linux:**
```bash
# Install required keyring
sudo apt-get install gnome-keyring  # or kwallet for KDE

# Verify Secret Service
secret-tool lookup service claude-code
```

**Windows:**
```powershell
# Check Credential Manager
cmdkey /list | findstr "claude-code"
```

### Index Not Updating
```bash
# Force re-index
/index-project --force

# Check ignored patterns in .claude/project-context.local.md
# Ensure your files aren't in ignored directories
```

### Resume Not Working
```bash
# Check session state file exists
ls -la .claude/.project-state.json

# Manually trigger resume
/resume --force
```

## Development

### Plugin Structure
```
project-context-manager/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── project-indexing/
│   ├── session-management/
│   ├── chunk-navigation/
│   └── secure-credential-handling/
├── commands/
│   ├── index-project.md
│   ├── resume.md
│   ├── chunk.md
│   ├── navigate.md
│   ├── context-summary.md
│   ├── evaluate.md
│   ├── store-credential.md
│   ├── get-credential.md
│   └── list-credentials.md
├── agents/
│   ├── project-indexer.md
│   ├── context-tracker.md
│   └── project-evaluator.md
├── hooks/
│   └── hooks.json
└── scripts/
    ├── keychain/
    ├── indexer/
    └── security/
```

## Contributing

This plugin is developed by QENEX Infrastructure Team for internal use. For bugs or feature requests, contact: ceo@qenex.ai

## License

MIT License - See LICENSE file for details

## Changelog

### v1.0.0 (2026-01-22)
- Initial release
- System keychain integration (macOS/Linux/Windows)
- Phase-based project chunking with semantic navigation
- Automatic session resumption with state tracking
- Plan mode integration with progress tracking
- Multi-language project support (Python, Rust, Go, Julia, Elixir, C++, Zig, JavaScript)
- Comprehensive leak prevention (git/bash/file-write scanning)
- Ruthless project evaluation system with genius recommendations
- 4 skills, 9 commands, 3 agents, 3 hooks
- Production-tested patterns from QENEX HFT platform
