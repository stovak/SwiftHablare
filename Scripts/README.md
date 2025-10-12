# SwiftHablare Scripts

Helper scripts for development and testing.

## Test Scripts

### `test.sh` - Test Runner with Automatic Keychain Unlocking

Runs the test suite with automatic keychain unlocking to avoid password prompts during test runs.

**Usage:**
```bash
# Run all tests
./Scripts/test.sh

# Run specific test suite
./Scripts/test.sh --filter TextRequestorTests

# Run tests in parallel
./Scripts/test.sh --parallel

# Pass any swift test arguments
./Scripts/test.sh --filter Phase6 --parallel
```

**Features:**
- Automatically detects if keychain is locked
- Prompts for password only once per session
- Configures keychain to not lock automatically
- Optional password file support for fully automated runs

**Password File (Optional):**

To avoid entering your password every time, you can save it to a file:

```bash
echo 'YOUR_KEYCHAIN_PASSWORD' > ~/.swifthablare-keychain-password
chmod 600 ~/.swifthablare-keychain-password
```

⚠️ **Security Note:** Only use the password file on trusted development machines. The password is stored in plain text.

### `unlock-keychain.sh` - Manual Keychain Unlock

Manually unlocks the keychain and configures it to stay unlocked.

**Usage:**
```bash
# Prompt for password
./Scripts/unlock-keychain.sh

# Provide password as argument (useful for automation)
./Scripts/unlock-keychain.sh "your-password"
```

**Features:**
- Unlocks the login keychain
- Sets keychain to not lock automatically
- Remains unlocked until system sleep/lock

## Keychain Configuration

The scripts configure your keychain with the following settings:

- **No automatic lock**: Keychain stays unlocked between test runs
- **Lock on sleep**: Keychain locks when system goes to sleep (security best practice)
- **Lock on screensaver**: Keychain locks when screen is locked

## Troubleshooting

### "Keychain is locked" during tests

Run the unlock script before running tests:
```bash
./Scripts/unlock-keychain.sh
swift test
```

Or use the test runner which does this automatically:
```bash
./Scripts/test.sh
```

### Tests still prompting for password

Your keychain might have a timeout configured. Reset it:
```bash
security set-keychain-settings -l ~/Library/Keychains/login.keychain-db
```

### Want to re-lock the keychain

```bash
security lock-keychain ~/Library/Keychains/login.keychain-db
```

## CI/CD Integration

For continuous integration, you can:

1. **GitHub Actions**: Use the `unlock-keychain` action or set up keychain in workflow
2. **Local CI**: Use the password file approach with `test.sh`
3. **Create test keychain**: Create a separate keychain for tests without a password

Example test keychain creation:
```bash
security create-keychain -p "" test.keychain
security set-keychain-settings test.keychain
security unlock-keychain -p "" test.keychain
security list-keychains -s test.keychain
```
