# Changelog

## [1.2.0] - 2026-01-22

### Added
- **Secure Credential Management Commands**
  - `/store-credential` - Store credentials in system keychain with project isolation
  - `/get-credential` - Retrieve stored credentials securely
  - `/list-credentials` - List all stored credentials by scope
  - `/delete-credential` - Delete credentials with confirmation prompt

### Improved
- Updated keychain-wrapper.sh with better error handling and fallback encryption
- Added scripts/credentials directory structure
- Enhanced plugin.json with proper command registration
- Multi-OS support: macOS Keychain, Linux Secret Service (with OpenSSL fallback), Windows Credential Manager

### Security
- AES-256-CBC encryption for fallback storage on Linux
- Per-project credential isolation (claude-code:project-name:cred-name)
- Global credential support for cross-project keys
- Automatic .gitignore protection

### Documentation
- Added comprehensive credential handling examples
- Updated README with credential management features
- Created skill documentation for secure-credential-handling

## [1.0.0] - 2026-01-22

### Initial Release
- Project indexing for polyglot codebases
- Phase-based project chunking
- Session management and resumption
- Plan mode integration
- Project evaluation framework

# Changelog

All notable changes to the Project Context Manager plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-22

### Added

#### Core Features
- **System keychain integration** for secure credential storage
  - macOS Keychain Access support
  - Linux Secret Service API support (gnome-keyring, kwallet)
  - Windows Credential Manager support
  - Per-project credential isolation
  - Encrypted storage at rest

- **Intelligent project indexing** with polyglot language detection
  - Automatic detection for 8 languages (Python, Rust, Go, Julia, Elixir, C++, Zig, JavaScript)
  - Dependency parsing (package.json, Cargo.toml, requirements.txt, go.mod, mix.exs, CMakeLists.txt, build.zig, package-lock.json)
  - File structure analysis and key file identification
  - Git repository integration
  - Auto-update on project switch

- **Phase-based project chunking** with semantic navigation
  - Three chunking strategies (phase-based, module-based, file-based)
  - Automatic phase detection from plan files
  - Dependency graph visualization
  - Syntax-highlighted chunk summaries
  - Context-aware navigation patterns

- **Session management and resumption**
  - Automatic state tracking (edited files, todos, plan context, current chunk)
  - Smart resume with context restoration
  - Session history with 30-session retention
  - 15-minute automatic checkpoints
  - Cross-session continuity

- **Ruthless project evaluation system**
  - Phase evaluation with 8 mandatory criteria
  - Project-wide assessment with architectural review
  - Quick health checks
  - Harsh scoring (79% ≠ 80%, F <60%)
  - Zero tolerance for TODOs, missing tests, or incomplete documentation

- **Genius recommendations addon**
  - 9 categories of optimizations (N+1 queries, caching, async, bundling, schema, monitoring, security, DevOps, testing)
  - Real production patterns from QENEX HFT platform
  - Measurable outcomes with before/after metrics
  - file:line references for all recommendations

#### Components Created
- **Skills (4)**
  - `project-indexing` - Polyglot language detection and project structure analysis
  - `session-management` - State tracking and session restoration
  - `chunk-navigation` - Semantic chunking and phase navigation
  - `secure-credential-handling` - System keychain integration and leak prevention

- **Commands (9)**
  - `/index-project` - Scan and index current project
  - `/context-summary` - Show project state and statistics
  - `/evaluate` - Ruthless phase/project evaluation
  - `/resume` - Resume from last session
  - `/chunk` - Create and manage project chunks
  - `/navigate` - Navigate between phases
  - `/store-credential` - Securely store credentials
  - `/get-credential` - Retrieve stored credentials
  - `/list-credentials` - List credential names

- **Agents (3)**
  - `project-indexer` - Autonomous project indexing
  - `context-tracker` - Automatic session state management
  - `project-evaluator` - Ruthless project assessment with recommendations

- **Hooks (3)**
  - `SessionStart` - Restore project context on session start
  - `Stop` - Save session state on session end
  - `PreToolUse` - Prevent credential leaks in git/bash/file operations

#### Utilities and Scripts
- **14 executable scripts**
  - Language detection (detect-languages.py)
  - Dependency scanning (scan-dependencies.sh)
  - Index generation (generate-index.py)
  - Phase creation (create-phases.py)
  - Dependency extraction (extract-deps.py)
  - Summary rendering (render-summary.sh)
  - Session history (session-history.py)
  - State restoration (restore-state.sh)
  - Keychain wrapper (keychain-wrapper.sh)
  - Hook scripts (session-start.sh, save-state.sh)
  - Validation scripts (validate-plugin.sh, validate-plugin-v2.sh, quick-validate.sh)

#### Documentation
- Comprehensive README with installation, configuration, and usage examples
- VALIDATION_REPORT.md documenting 100% validation pass (52+ files)
- TESTING_CHECKLIST.md with manual component verification
- 7 reference files across skills with detailed implementations
- 6 example files (JSON schemas, sample configurations)

### Security
- **Three-layer leak prevention**
  - PreToolUse hook scanning git commits, bash commands, and file writes
  - Pattern matching for API keys, tokens, private keys, passwords
  - Per-project credential isolation in system keychains
  - Credentials never stored in plain text or logs

### Validated
- ✅ All 14 scripts executable and functional
- ✅ All 8 JSON files have valid syntax
- ✅ All 4 skills have proper frontmatter and trigger phrases
- ✅ All 3 agents have required fields and examples
- ✅ All 9 commands have valid structure
- ✅ Hook configuration correct with portable paths
- ✅ Directory structure follows plugin standards
- ✅ Progressive disclosure properly implemented (SKILL.md <5k words, detailed content in references/)
- ✅ Paths use $CLAUDE_PLUGIN_ROOT for portability

### Tested
- Manual component verification completed
- Individual script testing passed
- JSON schema validation passed
- Structure validation passed
- Integration testing pending in Claude Code session

## [Unreleased]

### Future Enhancements
- Web-based project dashboard
- Multi-user collaboration features
- Cloud backup for session history
- Integration with external project management tools (Jira, Linear, Asana)
- Advanced dependency analysis with circular detection
- Performance profiling integration
- Automated code quality metrics
- Plugin marketplace submission

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 1.0.0 | 2026-01-22 | Initial release with keychain integration, project indexing, chunking, session management, and ruthless evaluation |

---

**Note**: This plugin was developed by QENEX Infrastructure Team and incorporates production patterns from the QENEX high-frequency trading platform.
