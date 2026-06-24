#!/bin/bash

# SecureFlow Git Secrets Setup Script
# Installs and configures git-secrets for secret scanning

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔒 Setting up git-secrets for SecureFlow..."

# Check if git-secrets is installed
if ! command -v git-secrets > /dev/null 2>&1; then
    echo "📦 Installing git-secrets..."
    
    # macOS
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command -v brew > /dev/null 2>&1; then
            brew install git-secrets
        else
            echo "❌ Homebrew not found. Please install Homebrew first."
            echo "   Visit: https://brew.sh"
            exit 1
        fi
    # Linux
    elif [[ "$(uname -s)" == "Linux" ]]; then
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y git-secrets
        elif command -v yum > /dev/null 2>&1; then
            sudo yum install -y git-secrets
        else
            echo "❌ Unsupported package manager. Please install git-secrets manually."
            echo "   Visit: https://github.com/awslabs/git-secrets"
            exit 1
        fi
    else
        echo "❌ Unsupported operating system. Please install git-secrets manually."
        echo "   Visit: https://github.com/awslabs/git-secrets"
        exit 1
    fi
fi

echo "✅ git-secrets installed successfully"

# Navigate to repository root
cd "$REPO_ROOT"

# Configure git-secrets for this repository
echo "🔧 Configuring git-secrets for this repository..."

# Register the patterns from .git-secrets file
if [[ -f ".git-secrets" ]]; then
    # Add patterns from .git-secrets file
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        [[ "$pattern" =~ ^#.*$ ]] && continue
        [[ -z "$pattern" ]] && continue
        
        git-secrets --add "$pattern" 2>/dev/null || true
    done < .git-secrets
    echo "✅ Added patterns from .git-secrets"
else
    echo "⚠️  .git-secrets file not found. Using default patterns."
    
    # Add default AWS patterns
    git-secrets --register-aws
    git-secrets --add 'password\s*[:=]\s*['"'"'"]?[a-zA-Z0-9_\-]{8,}['"'"'"]?'
    git-secrets --add 'api[_-]?key\s*[:=]\s*['"'"'"]?[a-zA-Z0-9_\-]{16,}['"'"'"]?'
    git-secrets --add 'secret[_-]?key\s*[:=]\s*['"'"'"]?[a-zA-Z0-9_\-]{16,}['"'"'"]?'
fi

# Install pre-commit hook
echo "🔧 Installing pre-commit hook..."
git-secrets --install
git-secrets --register-aws

# Scan existing repository for secrets
echo "🔍 Scanning existing repository for secrets..."
if ! git-secrets --scan; then
    echo ""
    echo "❌ SECURITY CHECK FAILED: Potential secrets found in repository!"
    echo ""
    echo "🔴 The following files contain patterns matching secrets:"
    echo ""
    git-secrets --scan 2>&1 | grep -E "(ERROR|Found)" || true
    echo ""
    echo "🛠️  REMEDIATION STEPS:"
    echo "   1. Review the files listed above"
    echo "   2. Remove or redact any actual secrets (API keys, passwords, tokens)"
    echo "   3. Replace with environment variables or secure configuration"
    echo "   4. Run 'git-secrets --scan' again to verify the fix"
    echo "   5. Re-run this script after fixing the issues"
    echo ""
    echo "⚠️  This script will NOT continue until all secrets are removed."
    echo "   This is a security requirement to prevent credential leakage."
    exit 1
fi
echo "✅ No secrets found in existing repository"

echo ""
echo "🎉 git-secrets setup complete!"
echo ""
echo "📋 Summary:"
echo "   - git-secrets installed and configured"
echo "   - Pre-commit hook installed"
echo "   - Repository scanned for secrets"
echo ""
echo "🔒 Your repository is now protected against accidental secret commits"
echo ""
echo "📖 Usage:"
echo "   - git-secrets --scan                    Scan entire repository"
echo "   - git-secrets --scan --no-index         Scan files without git index"
echo "   - git-secrets --add 'pattern'           Add custom pattern"
echo "   - git-secrets --list                    List all patterns"
