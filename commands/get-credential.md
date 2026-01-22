---
name: get-credential
description: Retrieve stored credential value (never logged or displayed)
allowed-tools:
  - Bash
---

# Get Credential Command

## High-Level Overview

Securely retrieve credential from system keychain for use in code execution. Credentials are:
- Never logged to console
- Never displayed to user
- Used directly in code/scripts
- Retrieved from OS-native keychain

**When to use:** When code needs API keys, tokens, or passwords. NOT for displaying credentials.

**Security:** This command retrieves sensitive values. Output should be used programmatically, never shown.

---

## Execution Flow

### Level 1: Core Process

1. **Parse arguments** → Get credential name and scope
2. **Construct service key** → Build keychain lookup key
3. **Retrieve from keychain** → Call keychain wrapper
4. **Return value silently** → Output for script use only

### Level 2: Detailed Implementation

#### Step 1: Parse Arguments

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Arguments
CREDENTIAL_NAME="$1"
GLOBAL_SCOPE=false

if [ "$2" = "--global" ]; then
  GLOBAL_SCOPE=true
fi

if [ -z "$CREDENTIAL_NAME" ]; then
  echo "Error: Credential name required" >&2
  echo "Usage: /get-credential <name> [--global]" >&2
  exit 1
fi
```

#### Step 2: Construct Service Key

```bash
if [ "$GLOBAL_SCOPE" = "true" ]; then
  SERVICE="claude-code:global:${CREDENTIAL_NAME}"
else
  SERVICE="claude-code:${PROJECT_NAME}:${CREDENTIAL_NAME}"
fi
```

#### Step 3: Retrieve from Keychain

```bash
# Call keychain wrapper (output goes to stdout for capture)
CREDENTIAL_VALUE=$(bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  retrieve \
  "$SERVICE" \
  "credential" 2>/dev/null)

if [ -z "$CREDENTIAL_VALUE" ]; then
  echo "Error: Credential '$CREDENTIAL_NAME' not found" >&2

  if [ "$GLOBAL_SCOPE" = "false" ]; then
    echo "Searched in project scope. Try --global flag?" >&2
  fi

  exit 1
fi
```

#### Step 4: Return Value Silently

```bash
# Output value to stdout ONLY (no messages, no logging)
echo "$CREDENTIAL_VALUE"
```

---

## Usage Patterns

### Pattern 1: Environment Variable

```bash
# Set for single command
API_KEY=$(/get-credential github-api) curl -H "Authorization: Bearer $API_KEY" https://api.github.com

# Or export for session
export ANTHROPIC_API_KEY=$(/get-credential anthropic-api)
```

### Pattern 2: Script Argument

```bash
# Pass to script
python deploy.py --api-key "$(/get-credential deploy-api)"

# Rust program
./target/release/trading-bot --token "$(/get-credential trading-token)"
```

### Pattern 3: Config File Generation

```bash
# Generate temporary config
cat > /tmp/config.json <<EOF
{
  "api_key": "$(/get-credential api-key)",
  "database": {
    "password": "$(/get-credential db-password)"
  }
}
EOF

# Use and cleanup
python app.py --config /tmp/config.json
rm /tmp/config.json
```

### Pattern 4: Git Credential Helper

```bash
# Use for git operations
GIT_TOKEN=$(/get-credential github-token)
git clone https://oauth2:$GIT_TOKEN@github.com/user/repo.git
```

---

## Arguments

- `<name>` - Credential identifier (required)
- `--global` - Search global scope instead of project scope
- `--verify-changed` - Verify credential was recently updated (returns exit code only)

---

## Output

### Success

```
<credential-value>
```

(No other output - value only)

### Error

```
Error: Credential 'api-key' not found
Searched in project scope. Try --global flag?
```

(Errors go to stderr, not stdout)

---

## Security Guarantees

**This command:**
- ✅ Retrieves from OS keychain
- ✅ Outputs to stdout for capture only
- ✅ Never logs credential value
- ✅ Never displays to user
- ✅ Fails silently if not found

**This command does NOT:**
- ❌ Display credentials in terminal
- ❌ Log to Claude Code logs
- ❌ Write to temp files
- ❌ Include in command history
- ❌ Trigger leak prevention warnings

---

## Error Codes

| Code | Meaning |
|------|---------|
| 0    | Success - credential retrieved |
| 1    | Credential not found |
| 2    | Keychain access denied |
| 3    | Invalid arguments |

---

## Best Practices

**DO:**
- Use in command substitution: `$(/ get-credential name)`
- Unset variables after use: `unset API_KEY`
- Use temporary files with 0600 permissions
- Clean up temp files immediately

**DON'T:**
- Echo or print credential value
- Store in permanent config files
- Commit generated configs to git
- Use in long-lived environment variables

---

## Comparison with store-credential

| Command | Purpose | User Interaction |
|---------|---------|------------------|
| `/store-credential` | Save credentials | Interactive, prompts user |
| `/get-credential` | Retrieve for use | Silent, returns value only |
| `/list-credentials` | Show names | Displays names (not values) |

---

## Integration with Leak Prevention

**PreToolUse hook scans for:**
- Credential patterns in bash commands
- Values in file writes
- Values in git commits

**If detected:**
```
⚠ Potential credential detected in command
  Pattern: api_key=<secret>
  Command: echo "api_key=$API_KEY" > config.yaml

Recommendation: Store in keychain, don't write to files
```

---

## Example Workflows

### Workflow 1: API Request

```bash
#!/bin/bash
# Fetch from authenticated API

API_KEY=$(/get-credential github-api)

curl -H "Authorization: Bearer $API_KEY" \
  https://api.github.com/user \
  | jq '.login'

unset API_KEY
```

### Workflow 2: Database Connection

```python
# Python script using credential
import subprocess
import psycopg2

db_password = subprocess.check_output([
    "bash", "-c", "/get-credential prod-db-password"
]).decode().strip()

conn = psycopg2.connect(
    host="db.example.com",
    database="production",
    user="admin",
    password=db_password
)

# Use connection
# ...

conn.close()
```

### Workflow 3: Temporary SSH Key

```bash
#!/bin/bash
# Use SSH key for deployment

# Retrieve key
/get-credential deploy-ssh-key > /tmp/deploy_key
chmod 600 /tmp/deploy_key

# Use key
ssh -i /tmp/deploy_key user@server "deploy.sh"

# Cleanup
rm -f /tmp/deploy_key
```

---

## Troubleshooting

**Credential not found:**
```bash
# Check if stored
/list-credentials | grep api-key

# Try global scope
/get-credential api-key --global

# Store if missing
/store-credential --name api-key --type api-key
```

**Keychain access denied:**
```bash
# macOS: Unlock keychain
security unlock-keychain ~/Library/Keychains/login.keychain-db

# Linux: Start keyring daemon
eval $(gnome-keyring-daemon --start)

# Windows: Run as Administrator
```

---

## Related Commands

- `/store-credential` - Store credentials securely
- `/list-credentials` - View credential names
- `/index-project` - Track credential requirements

## Related Skills

For detailed credential handling patterns, security best practices, and platform-specific troubleshooting:

`$CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/SKILL.md`
