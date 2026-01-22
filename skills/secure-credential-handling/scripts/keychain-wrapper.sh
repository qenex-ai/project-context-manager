#!/bin/bash
# Cross-platform keychain wrapper for credential storage
# Supports: macOS Keychain, Linux Secret Service, Windows Credential Manager

set -euo pipefail

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)

# Store credential in keychain
store_credential() {
    local service="$1"
    local account="$2"
    local password="$3"

    case "$PLATFORM" in
        macos)
            security add-generic-password \
                -a "$account" \
                -s "$service" \
                -w "$password" \
                -U 2>/dev/null
            ;;
        linux)
            echo "$password" | secret-tool store \
                --label="$service" \
                service "$service" \
                account "$account"
            ;;
        windows)
            cmdkey /generic:"$service" /user:"$account" /pass:"$password" > /dev/null
            ;;
        *)
            echo "ERROR: Unsupported platform: $PLATFORM" >&2
            return 1
            ;;
    esac
}

# Retrieve credential from keychain
retrieve_credential() {
    local service="$1"
    local account="$2"

    case "$PLATFORM" in
        macos)
            security find-generic-password \
                -a "$account" \
                -s "$service" \
                -w 2>/dev/null
            ;;
        linux)
            secret-tool lookup \
                service "$service" \
                account "$account" 2>/dev/null
            ;;
        windows)
            # Windows cmdkey doesn't support retrieval, use PowerShell
            powershell -Command "\
                \$cred = Get-StoredCredential -Target '$service'; \
                if (\$cred) { \$cred.GetNetworkCredential().Password }"
            ;;
        *)
            echo "ERROR: Unsupported platform: $PLATFORM" >&2
            return 1
            ;;
    esac
}

# Delete credential from keychain
delete_credential() {
    local service="$1"
    local account="$2"

    case "$PLATFORM" in
        macos)
            security delete-generic-password \
                -a "$account" \
                -s "$service" 2>/dev/null
            ;;
        linux)
            secret-tool clear \
                service "$service" \
                account "$account" 2>/dev/null
            ;;
        windows)
            cmdkey /delete:"$service" > /dev/null
            ;;
        *)
            echo "ERROR: Unsupported platform: $PLATFORM" >&2
            return 1
            ;;
    esac
}

# List credentials (names only)
list_credentials() {
    local service_prefix="$1"

    case "$PLATFORM" in
        macos)
            security dump-keychain | grep -A 1 "\"svce\"<blob>=\"$service_prefix" | \
                grep "\"acct\"<blob>" | sed 's/.*"acct"<blob>="\(.*\)".*/\1/'
            ;;
        linux)
            secret-tool search service "$service_prefix" 2>/dev/null | \
                grep "^attribute.account" | cut -d= -f2
            ;;
        windows)
            cmdkey /list | grep "$service_prefix" | sed 's/.*Target: \(.*\)/\1/'
            ;;
        *)
            echo "ERROR: Unsupported platform: $PLATFORM" >&2
            return 1
            ;;
    esac
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        store)
            if [ $# -ne 3 ]; then
                echo "Usage: $0 store <service> <account> <password>" >&2
                exit 1
            fi
            store_credential "$@"
            ;;
        retrieve)
            if [ $# -ne 2 ]; then
                echo "Usage: $0 retrieve <service> <account>" >&2
                exit 1
            fi
            retrieve_credential "$@"
            ;;
        delete)
            if [ $# -ne 2 ]; then
                echo "Usage: $0 delete <service> <account>" >&2
                exit 1
            fi
            delete_credential "$@"
            ;;
        list)
            if [ $# -ne 1 ]; then
                echo "Usage: $0 list <service_prefix>" >&2
                exit 1
            fi
            list_credentials "$@"
            ;;
        help|*)
            cat <<EOF
Cross-Platform Keychain Wrapper

Usage: $0 <command> [args...]

Commands:
    store <service> <account> <password>  Store credential
    retrieve <service> <account>          Retrieve credential
    delete <service> <account>            Delete credential
    list <service_prefix>                 List credentials (names only)

Platform: $PLATFORM

Examples:
    # Store
    $0 store "claude-code:project:api-key" "api" "sk-..."

    # Retrieve
    $0 retrieve "claude-code:project:api-key" "api"

    # Delete
    $0 delete "claude-code:project:api-key" "api"

    # List
    $0 list "claude-code:"
EOF
            [ "$command" = "help" ] && exit 0 || exit 1
            ;;
    esac
}

main "$@"
