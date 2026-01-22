---
name: list-credentials
description: List all stored credential names for current project (values hidden)
allowed-tools:
  - Bash
---

# List Credentials Command

## High-Level Overview

Display inventory of stored credentials showing:
- Credential names (identifiers)
- Credential types (api-key, ssh-key, oauth-token, database)
- Scope (project-specific or global)
- Creation/update timestamps (if available)

**Security:** Never displays actual credential values - names/types only.

**When to use:** To audit stored credentials, verify storage, or check what credentials exist before retrieval.

---

## Execution Flow

### Level 1: Core Process

1. **Determine scope** → Project-specific or global
2. **Query keychain** → List credential entries
3. **Parse results** → Extract names and types
4. **Format output** → Display organized list

### Level 2: Detailed Implementation

#### Step 1: Determine Project Context

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Check for --global flag
SCOPE="project"
if [ "$1" = "--global" ]; then
  SCOPE="global"
fi
```

#### Step 2: Query Keychain

```bash
if [ "$SCOPE" = "global" ]; then
  SERVICE_PREFIX="claude-code:global"
else
  SERVICE_PREFIX="claude-code:${PROJECT_NAME}"
fi

# List credentials from keychain
CREDENTIALS=$(bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  list \
  "$SERVICE_PREFIX" 2>/dev/null)

if [ -z "$CREDENTIALS" ]; then
  if [ "$SCOPE" = "global" ]; then
    echo "No global credentials found"
  else
    echo "No credentials found for project: $PROJECT_NAME"
  fi

  echo ""
  echo "Store credentials with: /store-credential --name <name> --type <type>"
  exit 0
fi
```

#### Step 3: Parse and Categorize

```bash
# Categorize by type
API_KEYS=()
SSH_KEYS=()
OAUTH_TOKENS=()
DATABASES=()
UNKNOWN=()

while IFS= read -r cred; do
  # Extract name from service string
  # Format: claude-code:project:name or claude-code:global:name
  CRED_NAME=$(echo "$cred" | sed "s|$SERVICE_PREFIX:||")

  # Determine type (heuristic based on name patterns)
  if echo "$CRED_NAME" | grep -qiE "api|key"; then
    API_KEYS+=("$CRED_NAME")
  elif echo "$CRED_NAME" | grep -qiE "ssh|deploy|private"; then
    SSH_KEYS+=("$CRED_NAME")
  elif echo "$CRED_NAME" | grep -qiE "oauth|token"; then
    OAUTH_TOKENS+=("$CRED_NAME")
  elif echo "$CRED_NAME" | grep -qiE "db|database|postgres|mysql"; then
    DATABASES+=("$CRED_NAME")
  else
    UNKNOWN+=("$CRED_NAME")
  fi
done <<< "$CREDENTIALS"

TOTAL_COUNT=$(echo "$CREDENTIALS" | wc -l)
```

#### Step 4: Display Organized List

```bash
echo "═══════════════════════════════════════════════"
if [ "$SCOPE" = "global" ]; then
  echo "  Global Credentials"
else
  echo "  Credentials: $PROJECT_NAME"
fi
echo "═══════════════════════════════════════════════"
echo ""

echo "Total: $TOTAL_COUNT credentials"
echo ""

# Display by category
if [ ${#API_KEYS[@]} -gt 0 ]; then
  echo "API Keys (${#API_KEYS[@]}):"
  for key in "${API_KEYS[@]}"; do
    echo "  • $key"
  done
  echo ""
fi

if [ ${#SSH_KEYS[@]} -gt 0 ]; then
  echo "SSH Keys (${#SSH_KEYS[@]}):"
  for key in "${SSH_KEYS[@]}"; do
    echo "  • $key"
  done
  echo ""
fi

if [ ${#OAUTH_TOKENS[@]} -gt 0 ]; then
  echo "OAuth Tokens (${#OAUTH_TOKENS[@]}):"
  for token in "${OAUTH_TOKENS[@]}"; do
    echo "  • $token"
  done
  echo ""
fi

if [ ${#DATABASES[@]} -gt 0 ]; then
  echo "Database Credentials (${#DATABASES[@]}):"
  for db in "${DATABASES[@]}"; do
    echo "  • $db"
  done
  echo ""
fi

if [ ${#UNKNOWN[@]} -gt 0 ]; then
  echo "Other (${#UNKNOWN[@]}):"
  for item in "${UNKNOWN[@]}"; do
    echo "  • $item"
  done
  echo ""
fi
```

#### Step 5: Usage Hints

```bash
echo "═══════════════════════════════════════════════"
echo ""
echo "To retrieve a credential:"
echo "  /get-credential <name>"
echo ""
echo "To delete a credential:"
echo "  /store-credential --name <name> --delete"
echo ""

if [ "$SCOPE" = "project" ]; then
  echo "To view global credentials:"
  echo "  /list-credentials --global"
  echo ""
fi
```

---

## Arguments

- `--global` - List global credentials (all projects)
- `--json` - Output in JSON format
- `--verbose` - Include creation timestamps (if available)

---

## Output Formats

### Standard Output

```
═══════════════════════════════════════════════
  Credentials: qenex
═══════════════════════════════════════════════

Total: 7 credentials

API Keys (3):
  • github-api
  • anthropic-api
  • stripe-api

SSH Keys (2):
  • deploy-key
  • github-deploy

Database Credentials (2):
  • prod-db
  • staging-db

═══════════════════════════════════════════════

To retrieve a credential:
  /get-credential <name>

To delete a credential:
  /store-credential --name <name> --delete

To view global credentials:
  /list-credentials --global
```

### Global Scope

```
═══════════════════════════════════════════════
  Global Credentials
═══════════════════════════════════════════════

Total: 3 credentials

API Keys (2):
  • anthropic-api-global
  • openai-api-global

OAuth Tokens (1):
  • google-oauth-global

═══════════════════════════════════════════════

To retrieve a credential:
  /get-credential <name> --global
```

### JSON Output (`--json`)

```json
{
  "scope": "project",
  "project_name": "qenex",
  "total_count": 7,
  "credentials": {
    "api_keys": [
      {"name": "github-api"},
      {"name": "anthropic-api"},
      {"name": "stripe-api"}
    ],
    "ssh_keys": [
      {"name": "deploy-key"},
      {"name": "github-deploy"}
    ],
    "databases": [
      {"name": "prod-db"},
      {"name": "staging-db"}
    ]
  }
}
```

### Empty State

```
No credentials found for project: myproject

Store credentials with: /store-credential --name <name> --type <type>
```

---

## Use Cases

### Audit Credentials

```bash
# Check what's stored
/list-credentials

# Check global credentials
/list-credentials --global

# Verify specific credential exists
/list-credentials | grep github-api
```

### Pre-Deployment Check

```bash
#!/bin/bash
# Verify required credentials before deployment

REQUIRED=("github-api" "deploy-key" "prod-db")
STORED=$(/list-credentials | grep -E "^  •" | sed 's/^  • //')

for cred in "${REQUIRED[@]}"; do
  if ! echo "$STORED" | grep -q "^$cred$"; then
    echo "Missing credential: $cred"
    exit 1
  fi
done

echo "✓ All required credentials present"
```

### Credential Migration

```bash
# List credentials from old project
cd /old-project
/list-credentials > /tmp/old_creds.txt

# Compare with new project
cd /new-project
/list-credentials > /tmp/new_creds.txt

diff /tmp/old_creds.txt /tmp/new_creds.txt
```

---

## Security Considerations

**What is shown:**
- ✅ Credential names (identifiers)
- ✅ Credential types (categories)
- ✅ Count of credentials
- ✅ Scope (project vs global)

**What is NOT shown:**
- ❌ Actual credential values
- ❌ Passwords, tokens, or keys
- ❌ Sensitive metadata
- ❌ Last access times (could leak usage patterns)

**Safe to share:**
- This output can be shared in documentation
- Safe to commit list to version control
- Safe to include in bug reports

**Not safe to share:**
- `/get-credential` output
- Actual credential values
- Credential storage file paths

---

## Integration with Other Components

**Project Indexing:**
```json
{
  "credentials_required": [
    "github-api",
    "stripe-api"
  ]
}
```

Index can track which credentials project needs.

**Session Management:**

On session restore, verify credentials exist:
```bash
/resume
# Internally checks: /list-credentials | grep <required>
```

**Plan Mode:**

Plans can reference credential names:
```markdown
## Phase 3: Deployment

- [ ] Verify credentials present: `/list-credentials`
- [ ] Deploy with: `DEPLOY_KEY=$(/get-credential deploy-key) ./deploy.sh`
```

---

## Troubleshooting

**No credentials listed but should exist:**

```bash
# Check keychain access
# macOS:
security find-generic-password -s "claude-code"

# Linux:
secret-tool search service "claude-code"

# Verify project name matches
basename $(git rev-parse --show-toplevel)
```

**Credentials in wrong scope:**

```bash
# Check both scopes
/list-credentials              # Project scope
/list-credentials --global     # Global scope

# Move from global to project
/get-credential api-key --global | \
  /store-credential --name api-key --type api-key --stdin
```

**Duplicate credential names:**

Credentials are scoped by project, so same name in different projects is safe:

```
/project-a/: github-api
/project-b/: github-api  # Different value, same name
```

---

## Performance

**Fast execution:**
- Queries keychain index only
- No credential values retrieved
- Typical runtime: <0.5 seconds

**Large credential counts:**
- Handles 100+ credentials efficiently
- Categorization helps organization
- Use `grep` to filter specific types

---

## Best Practices

**Regular audits:**
```bash
# Monthly credential review
/list-credentials
# Remove unused credentials
```

**Documentation:**
```bash
# Document required credentials in README
echo "Required credentials:" > CREDENTIALS.md
/list-credentials >> CREDENTIALS.md
```

**Team onboarding:**
```bash
# New developer setup checklist
/list-credentials
# Shows what credentials they need to configure
```

---

## Related Commands

- `/store-credential` - Add new credentials
- `/get-credential` - Retrieve credential values
- `/context-summary` - Includes credential count

## Related Skills

For detailed credential management patterns and security best practices:

`$CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/SKILL.md`
