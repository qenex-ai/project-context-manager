---
name: store-credential
description: Securely store credentials (API keys, SSH keys, OAuth tokens, database passwords) in system keychain with per-project isolation
allowed-tools:
  - Bash
  - AskUserQuestion
---

# Store Credential Command

You are executing the `/store-credential` command to securely store a credential in the system keychain.

## Purpose

Store sensitive credentials (API keys, private keys, OAuth tokens, database passwords) using native OS keychains with per-project isolation and comprehensive leak prevention.

## Arguments

Parse the user's command for these optional arguments:

- `--name <name>` - Credential identifier (required)
- `--type <type>` - Credential type: api-key, ssh-key, oauth-token, database (required)
- `--value <value>` - Credential value (for simple strings)
- `--file <path>` - Read credential from file (for keys)
- `--stdin` - Read credential from stdin
- `--global` - Store globally (default: project-scoped)

**Additional fields for database credentials:**
- `--username <user>`
- `--password <pass>`
- `--host <hostname>`
- `--port <port>`
- `--database <dbname>`

## Execution Steps

### 1. Determine Project Context

```bash
# Get project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
```

### 2. Validate Arguments

Check that required arguments are provided:
- `--name` is required
- `--type` is required
- At least one of `--value`, `--file`, or `--stdin` must be provided

If arguments are missing, use AskUserQuestion to gather them:

```
Question: "What should this credential be named?"
Options:
  - api-key (Common names: github-api, stripe-api, anthropic-api)
  - ssh-key (Common names: deploy-key, github-deploy, server-key)
  - oauth-token (Common names: google-oauth, github-token)
  - database (Common names: prod-db, staging-db, local-db)
```

### 3. Construct Service Name

Build hierarchical service name for keychain:

```bash
if [ "$GLOBAL" = "true" ]; then
  SERVICE="claude-code:global:${NAME}"
else
  SERVICE="claude-code:${PROJECT_NAME}:${NAME}"
fi
```

### 4. Get Credential Value

Based on input method:

**From --value:**
```bash
CREDENTIAL_VALUE="$VALUE"
```

**From --file:**
```bash
if [ ! -f "$FILE" ]; then
  echo "Error: File not found: $FILE"
  exit 1
fi
CREDENTIAL_VALUE=$(cat "$FILE")
```

**From --stdin:**
```bash
CREDENTIAL_VALUE=$(cat)
```

**Interactive prompt (if no input method specified):**
Use AskUserQuestion to securely prompt for credential value.

### 5. Store in Keychain

Call the keychain wrapper script:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  store \
  "$SERVICE" \
  "$TYPE" \
  "$CREDENTIAL_VALUE"
```

### 6. Verify Storage

```bash
# Verify credential was stored (without retrieving value)
bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  list \
  "claude-code:${PROJECT_NAME}" | grep -q "$NAME"

if [ $? -eq 0 ]; then
  echo "✓ Credential '$NAME' stored successfully"
  echo "  Scope: $([ "$GLOBAL" = "true" ] && echo "Global" || echo "Project: $PROJECT_NAME")"
  echo "  Type: $TYPE"
else
  echo "✗ Failed to store credential"
  exit 1
fi
```

### 7. Add to .gitignore

Ensure credential files never get committed:

```bash
# Add .credentials.enc to project .gitignore if not present
if ! grep -q ".credentials.enc" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
  echo ".credentials.enc" >> "$PROJECT_ROOT/.gitignore"
  echo "*.vault" >> "$PROJECT_ROOT/.gitignore"
fi
```

## Special Cases

### Database Credentials

For `--type database`, store as JSON structure:

```bash
CREDENTIAL_JSON=$(cat <<EOF
{
  "username": "$USERNAME",
  "password": "$PASSWORD",
  "host": "$HOST",
  "port": "$PORT",
  "database": "$DATABASE",
  "type": "database"
}
EOF
)

# Store JSON string
bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  store \
  "$SERVICE" \
  "database" \
  "$CREDENTIAL_JSON"
```

### OAuth Tokens

For `--type oauth-token`, include expiry and refresh token fields if provided.

## Security Notes

**Never log credential values:**
- Do not echo the credential value
- Do not include credentials in command output
- Do not write credentials to temporary files without secure permissions (0600)

**Leak prevention:**
The PreToolUse hook will scan for credential patterns before git commits or file writes.

## Output Format

**Success:**
```
✓ Credential 'github-api' stored successfully
  Scope: Project: qenex
  Type: api-key
  Location: System keychain (macOS Keychain)
```

**Error:**
```
✗ Failed to store credential 'github-api'
  Reason: Keychain access denied

Troubleshooting:
  macOS: Grant Terminal/Claude Code keychain access in System Preferences
  Linux: Ensure gnome-keyring or kwallet is running
  Windows: Run as Administrator if Credential Manager access fails
```

## Usage Examples

**Store API key interactively:**
```
/store-credential --name github-api --type api-key
```

**Store SSH key from file:**
```
/store-credential --name deploy-key --type ssh-key --file ~/.ssh/deploy_key
```

**Store database credentials:**
```
/store-credential --name prod-db --type database \
  --username admin \
  --password "$DB_PASS" \
  --host db.example.com \
  --port 5432 \
  --database production
```

**Store global credential (all projects):**
```
/store-credential --name anthropic-api --type api-key --global
```

## Related Skills

This command uses the **secure-credential-handling** skill. For detailed information about credential types, storage patterns, and security best practices, refer to:

`$CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/SKILL.md`
