#!/bin/bash
# Pre-push CI simulation script
# This script runs the same checks as GitHub Actions CI locally

set -e  # Exit on any error

echo "🧹 Step 1: Cleaning build artifacts..."
forge clean

echo ""
echo "📝 Step 2: Checking code formatting..."
if forge fmt --check; then
    echo "✅ Code formatting is correct"
else
    echo "❌ Code formatting issues found. Run 'forge fmt' to fix."
    exit 1
fi

echo ""
echo "📦 Step 3: Verifying dependencies..."
echo "Checking Git submodules..."
git submodule status

echo "Checking LayerZero-v2..."
if [ -d "lib/LayerZero-v2" ]; then
    echo "✅ LayerZero-v2 found"
else
    echo "❌ LayerZero-v2 not found. Run 'git submodule update --init --recursive'"
    exit 1
fi

echo "Checking OpenZeppelin contracts..."
if [ -d "lib/openzeppelin-contracts-upgradeable" ]; then
    echo "✅ openzeppelin-contracts-upgradeable found"
else
    echo "❌ openzeppelin-contracts-upgradeable not found"
    exit 1
fi

echo ""
echo "🔨 Step 4: Building project..."
forge build --sizes

echo ""
echo "🧪 Step 5: Running tests (ProtocolTest only - no RPC required)..."
forge test -vv --match-contract "ProtocolTest" --no-match-test "testExecuteBuyback"

echo ""
echo "📊 Step 6: Generating gas snapshot..."
forge snapshot --match-contract "ProtocolTest" --no-match-test "testExecuteBuyback"

echo ""
echo "✅ =============================================="
echo "✅ All checks passed! Safe to push to GitHub."
echo "✅ =============================================="

