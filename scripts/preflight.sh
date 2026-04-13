#!/usr/bin/env bash
set -euo pipefail

# Preflight check — verify all required tools are installed

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
ERRORS=0

check_command() {
    local cmd="$1"
    local min_version="${2:-}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$($cmd --version 2>&1 | head -1)
        echo -e "${GREEN}[OK]${NC} $cmd — $version"
    else
        echo -e "${RED}[MISSING]${NC} $cmd is not installed"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "=== Platform MVP Preflight Check ==="
echo ""

check_command "terraform"
check_command "aws"
check_command "kubectl"
check_command "helm"
check_command "docker"
check_command "ansible"
check_command "ansible-lint"
check_command "jq"
check_command "curl"
check_command "git"

echo ""

# Check AWS credentials
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}[OK]${NC} AWS credentials valid — Account: $ACCOUNT"
else
    echo -e "${RED}[FAIL]${NC} AWS credentials not configured or expired"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}Preflight failed with $ERRORS error(s)${NC}"
    exit 1
else
    echo -e "${GREEN}All preflight checks passed${NC}"
fi
