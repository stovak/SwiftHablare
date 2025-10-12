#!/bin/bash
#
# unlock-keychain.sh
# Unlocks the keychain for test runs
#
# Usage:
#   ./Scripts/unlock-keychain.sh [password]
#
# If no password is provided, it will prompt for one.
# The keychain will remain unlocked until the system sleeps or locks.

set -e

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

# Check if keychain exists
if [ ! -f "$KEYCHAIN" ]; then
    echo "❌ Keychain not found at: $KEYCHAIN"
    exit 1
fi

echo "🔓 Unlocking keychain: $KEYCHAIN"

# If password provided as argument, use it
if [ -n "$1" ]; then
    security unlock-keychain -p "$1" "$KEYCHAIN"
else
    # Otherwise, prompt for password
    security unlock-keychain "$KEYCHAIN"
fi

# Set keychain settings to not lock automatically
echo "⚙️  Setting keychain to not lock automatically..."
security set-keychain-settings -l "$KEYCHAIN"

echo "✅ Keychain unlocked and configured!"
echo ""
echo "The keychain will now remain unlocked for test runs."
echo "It will lock again when:"
echo "  - The system goes to sleep"
echo "  - The screen is locked"
echo "  - You log out"
