#!/bin/bash
# Test suite for safety-check.sh hook
# Run from the repo root: bash .claude/hooks/test-safety-hook.sh

HOOK_SCRIPT=".claude/hooks/safety-check.sh"
PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test helpers
test_should_block() {
    local cmd="$1"
    local description="$2"

    echo -n "Test: $description ... "

    if bash "$HOOK_SCRIPT" "$cmd" "Bash" 2>/dev/null; then
        echo -e "${RED}FAIL${NC} (command was not blocked)"
        ((FAILED++))
        return 1
    else
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    fi
}

test_should_allow() {
    local cmd="$1"
    local description="$2"

    echo -n "Test: $description ... "

    if bash "$HOOK_SCRIPT" "$cmd" "Bash" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} (command was blocked)"
        ((FAILED++))
        return 1
    fi
}

echo "========================================"
echo "  Claude Code Safety Hook Test Suite"
echo "========================================"
echo ""

# Database tests
echo "Database safety:"
test_should_block "DROP DATABASE mydb" "Block DROP DATABASE"
test_should_block "DROP TABLE users" "Block DROP TABLE"
test_should_block "psql -c 'DROP SCHEMA public'" "Block DROP SCHEMA"
test_should_block "TRUNCATE users" "Block TRUNCATE (cannot be filtered)"
test_should_block "psql -c 'DELETE FROM users' -h prod-db.example.com" "Block DELETE without WHERE on production"
test_should_allow "SELECT * FROM users WHERE id=1" "Allow SELECT queries"
echo ""

# Git tests
echo "Git safety:"
test_should_block "git push --force origin main" "Block force push to main"
test_should_block "git push --force origin master" "Block force push to master"
test_should_block "git branch -D main" "Block deletion of main branch"
test_should_block "git branch -D master" "Block deletion of master branch"
test_should_allow "git push origin feature/test" "Allow normal push to feature branch"
test_should_allow "git status" "Allow git status"
test_should_allow "git log --oneline" "Allow git log"
echo ""

# Docker tests
echo "Docker safety:"
test_should_block "docker system prune -a" "Block docker system prune -a"
test_should_block "docker rm -f prod-backend" "Block force removal of prod container"
test_should_allow "docker ps" "Allow docker ps"
test_should_allow "docker logs my-backend" "Allow docker logs"
echo ""

# Publishing tests
echo "Package publishing safety:"
test_should_block "npm publish" "Block npm publish"
test_should_block "pnpm publish" "Block pnpm publish"
test_should_block "yarn publish" "Block yarn publish"
test_should_allow "npm install" "Allow npm install"
test_should_allow "npm ci" "Allow npm ci"
test_should_allow "npm test" "Allow npm test"
echo ""

# Filesystem tests
echo "Filesystem safety:"
test_should_block "rm -rf .git" "Block deletion of .git"
test_should_block "rm -rf src" "Block deletion of src directory"
test_should_block "rm -rf backend" "Block deletion of backend directory"
test_should_block "rm .env" "Block deletion of .env"
test_should_allow "rm -rf node_modules" "Allow deletion of node_modules"
test_should_allow "rm -rf dist" "Allow deletion of dist"
test_should_allow "rm -rf build" "Allow deletion of build artifacts"
test_should_allow "rm -rf coverage" "Allow deletion of coverage"
echo ""

# Secrets tests
echo "Secrets safety:"
test_should_block "git add .env" "Block staging of .env"
test_should_block "git add secrets.pem" "Block staging of .pem files"
test_should_allow "export PASSWORD=\$DB_PASSWORD" "Allow environment variables"
test_should_allow "echo \$JWT_SECRET" "Allow environment variable reads"
echo ""

# Production identifier tests
echo "Production identifiers:"
test_should_allow "psql -h TODO-your-prod-db -c 'SELECT * FROM users WHERE id=1'" "Allow read operations on production"
test_should_allow "gcloud sql instances describe TODO-your-prod-db" "Allow describe operations"
test_should_allow "curl https://prod.example.com/health" "Allow API health calls"
echo ""

# Summary
echo ""
echo "========================================"
echo "  Test Results"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
