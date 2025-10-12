#!/bin/bash
#
# test.sh
# Runs tests with automatic keychain unlocking
#
# Usage:
#   ./Scripts/test.sh [swift test arguments...]
#
# Examples:
#   ./Scripts/test.sh                           # Run all tests
#   ./Scripts/test.sh --filter TextRequestorTests  # Run specific tests
#   ./Scripts/test.sh --parallel                # Run tests in parallel

set -e

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
KEYCHAIN_PASSWORD_FILE="${HOME}/.swifthablare-keychain-password"

echo "🧪 SwiftHablare Test Runner"
echo ""

# Check if keychain is already unlocked
if security show-keychain-info "$KEYCHAIN" 2>&1 | grep -q "no-timeout"; then
    # Try to access keychain without password to see if it's unlocked
    if security unlock-keychain -p "" "$KEYCHAIN" 2>/dev/null; then
        echo "✅ Keychain is already unlocked"
    else
        echo "🔓 Unlocking keychain..."

        # Check if password file exists
        if [ -f "$KEYCHAIN_PASSWORD_FILE" ]; then
            echo "📄 Using saved keychain password from: $KEYCHAIN_PASSWORD_FILE"
            KEYCHAIN_PASSWORD=$(cat "$KEYCHAIN_PASSWORD_FILE")
            security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
            echo "✅ Keychain unlocked"
        else
            echo "Please unlock your keychain:"
            security unlock-keychain "$KEYCHAIN"
            echo "✅ Keychain unlocked"
            echo ""
            echo "💡 Tip: To avoid entering your password every time, you can save it to:"
            echo "   echo 'YOUR_PASSWORD' > ~/.swifthablare-keychain-password"
            echo "   chmod 600 ~/.swifthablare-keychain-password"
        fi

        # Configure keychain to not lock
        security set-keychain-settings -l "$KEYCHAIN"
    fi
else
    echo "⚠️  Keychain timeout detected. Setting to no timeout..."
    security set-keychain-settings -l "$KEYCHAIN"
fi

echo ""
echo "▶️  Running tests..."
echo ""

# Run swift test with all provided arguments
swift test "$@"

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed with exit code: $TEST_EXIT_CODE"
fi

exit $TEST_EXIT_CODE
