#!/bin/bash
# Claude Code Safety Hook — prevents dangerous operations.
# Blocks commands that could damage production or delete important data.
#
# Wired up as a PreToolUse hook in .claude/settings.json:
#   CMD=$(cat | jq -r '.tool_input.command // empty') && bash .claude/hooks/safety-check.sh "$CMD" "Bash"
#
# Principle: prevent accidental mistakes, not deliberate choices.
# Read operations (SELECT, GET, LIST, STATUS, LOGS) always pass through.
#
# TODO: Fill in PROD_IDENTIFIERS below with your project's production
# identifiers (DB instance names, hostnames, IPs). Uncomment and adapt the
# provider-specific example sections (GCP, Supabase/Expo) if they apply.

COMMAND="$1"
TOOL_NAME="$2"

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper to block a command
block_command() {
    local reason="$1"
    echo -e "${RED}SAFETY BLOCK: $reason${NC}" >&2
    echo -e "${YELLOW}Blocked command: $COMMAND${NC}" >&2
    exit 1
}

# Helper for warnings (allow but warn)
warn_command() {
    local reason="$1"
    echo -e "${YELLOW}WARNING: $reason${NC}" >&2
}

# ============================================================================
# DATABASE SAFETY
# ============================================================================

# Block DROP DATABASE/TABLE/SCHEMA commands
if echo "$COMMAND" | grep -iE "(DROP\s+(DATABASE|TABLE|SCHEMA))" >/dev/null; then
    block_command "DROP DATABASE/TABLE/SCHEMA is forbidden. Use migrations instead."
fi

# Block TRUNCATE (it cannot be filtered — deletes every row in the table)
if echo "$COMMAND" | grep -iE "TRUNCATE\s+\w+" >/dev/null; then
    block_command "TRUNCATE deletes all rows and cannot be filtered. Use DELETE with a WHERE clause, or a migration."
fi

# Block DELETE/UPDATE without WHERE against production
if echo "$COMMAND" | grep -iE "(DELETE|UPDATE)\s+\w+" >/dev/null && ! echo "$COMMAND" | grep -iE "WHERE" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(\bprod\b|\bproduction\b|TODO-your-prod-db)" >/dev/null; then
        block_command "DELETE/UPDATE without WHERE is forbidden on production databases."
    fi
    warn_command "DELETE/UPDATE without WHERE — be careful!"
fi

# Block DROP COLUMN on production
if echo "$COMMAND" | grep -iE "ALTER\s+TABLE.*DROP\s+COLUMN" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(\bprod\b|\bproduction\b|TODO-your-prod-db)" >/dev/null; then
        block_command "DROP COLUMN on production requires a migration. Use the migration system."
    fi
fi

# ============================================================================
# GIT SAFETY
# ============================================================================

# Block force push to main/master
if echo "$COMMAND" | grep -iE "git\s+push.*--force" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(main|master)" >/dev/null; then
        block_command "Force push to main/master is forbidden. This can destroy commit history."
    fi
    warn_command "Force push can destroy history. Only use on feature branches."
fi

# Block git reset --hard on main/master
if echo "$COMMAND" | grep -iE "git\s+reset\s+--hard" >/dev/null; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        block_command "git reset --hard on main/master is forbidden. Check out a feature branch first."
    fi
    warn_command "git reset --hard permanently deletes uncommitted changes."
fi

# Block deletion of main/master branch
if echo "$COMMAND" | grep -iE "git\s+branch\s+-D\s+(main|master)" >/dev/null; then
    block_command "Deleting the main/master branch is forbidden."
fi

# Warn on git clean -fdx (deletes ALL untracked files)
if echo "$COMMAND" | grep -E "git\s+clean\s+.*-[a-z]*f.*-[a-z]*d.*-[a-z]*x" >/dev/null; then
    warn_command "git clean -fdx deletes ALL untracked files including .env and node_modules."
fi

# ============================================================================
# DOCKER & CONTAINER SAFETY
# ============================================================================

# Block docker system prune -a (deletes all images)
if echo "$COMMAND" | grep -E "docker\s+system\s+prune.*-a" >/dev/null; then
    block_command "docker system prune -a deletes all images. Too dangerous for automation."
fi

# Block force removal of production containers
if echo "$COMMAND" | grep -iE "docker\s+(rm|stop|kill).*-f" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(\bprod\b|\bproduction\b|TODO-your-prod-db)" >/dev/null; then
        block_command "Force removal of production containers is forbidden. Use graceful shutdown."
    fi
fi

# Warn on docker volume prune
if echo "$COMMAND" | grep -E "docker\s+volume\s+prune" >/dev/null; then
    warn_command "docker volume prune can delete database volumes. Double-check first."
fi

# ============================================================================
# PACKAGE PUBLISHING & DEPLOYMENT SAFETY
# ============================================================================

# Block package publishing (accidental releases)
if echo "$COMMAND" | grep -E "^(npm|pnpm|yarn)\s+publish" >/dev/null; then
    block_command "npm/pnpm/yarn publish is forbidden via automation. Publish manually after review."
fi

# Warn on npm install without ci in CI/CD
if echo "$COMMAND" | grep -E "^npm\s+install" >/dev/null && [ -n "$CI" ]; then
    warn_command "In CI/CD, use 'npm ci' instead of 'npm install' for reproducible builds."
fi

# ============================================================================
# FILESYSTEM SAFETY
# ============================================================================

# Block rm -rf on critical directories (allow build artifacts)
if echo "$COMMAND" | grep -E "rm\s+.*-[a-z]*r[a-z]*f" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(\.git|node_modules|src|backend|frontend|apps|packages|\*|/)" >/dev/null; then
        # Allow node_modules and common build-artifact cleanups
        if ! echo "$COMMAND" | grep -E "(node_modules|dist|build|\.next|\.expo|\.turbo|coverage|\.context)" >/dev/null; then
            block_command "rm -rf on important directories is forbidden. Too dangerous for automation."
        fi
    fi
fi

# Block deletion of .env files
if echo "$COMMAND" | grep -E "rm.*\.env" >/dev/null; then
    block_command "Deleting .env files is forbidden. They contain critical secrets."
fi

# ============================================================================
# SCHEMA & MIGRATION SAFETY
# ============================================================================

# Warn on direct schema changes against production
if echo "$COMMAND" | grep -iE "(ALTER|CREATE)\s.*TABLE" >/dev/null; then
    if echo "$COMMAND" | grep -iE "(\bprod\b|\bproduction\b|TODO-your-prod-db)" >/dev/null; then
        warn_command "Direct schema change on production. Use the migration system instead."
    fi
fi

# ============================================================================
# PASSWORDS & SECRETS SAFETY
# ============================================================================

# Warn on plaintext passwords on the command line
if echo "$COMMAND" | grep -iE "(password|passwd|pwd)=" >/dev/null; then
    if ! echo "$COMMAND" | grep -E "\\\$\{?[A-Z_]+\}?" >/dev/null; then
        warn_command "Plaintext password in the command. Use environment variables instead."
    fi
fi

# Block staging of sensitive files
if echo "$COMMAND" | grep -E "git\s+add.*\.(env|pem|key|crt)" >/dev/null && ! echo "$COMMAND" | grep -E "\.example" >/dev/null; then  # *.example files are meant to be committed
    block_command "Attempt to stage sensitive files (.env, .pem, .key, .crt). Use .gitignore."
fi

# ============================================================================
# PRODUCTION IDENTIFIERS
# ============================================================================

# List of production identifiers that require extra caution.
# TODO: Replace/extend with your project's DB instance names, prod hostnames, IPs.
# Regex patterns with word boundaries — plain "prod" would also match e.g. "products"
PROD_IDENTIFIERS=(
    "TODO-your-prod-db"
    "\bprod\b"
    "\bproduction\b"
)

# Check whether the command touches a production identifier
for identifier in "${PROD_IDENTIFIERS[@]}"; do
    if echo "$COMMAND" | grep -iE "$identifier" >/dev/null; then
        # Read operations (SELECT, GET, DESCRIBE, etc.) are OK
        if echo "$COMMAND" | grep -iE "(SELECT|GET|DESCRIBE|LIST|SHOW|VIEW|READ|LOGS|STATUS)" >/dev/null; then
            # Read operations are OK
            :
        else
            # Destructive operations get an extra warning
            if echo "$COMMAND" | grep -iE "(DELETE|DROP|TRUNCATE|REMOVE|KILL|STOP|RESTART|RESET)" >/dev/null; then
                warn_command "Destructive operation on a production identifier detected: $identifier"
            fi
        fi
    fi
done

# ============================================================================
# EXAMPLE: GOOGLE CLOUD PRODUCTION SAFETY (uncomment and adapt if you use GCP)
# ============================================================================

# # Block deletion of production resources
# if echo "$COMMAND" | grep -iE "gcloud\s+(sql\s+instances|compute\s+instances|run\s+services)\s+delete" >/dev/null; then
#     if echo "$COMMAND" | grep -iE "(TODO-your-prod-db|prod|production)" >/dev/null; then
#         block_command "Deleting production resources (DB, VM, Cloud Run) is forbidden via automation."
#     fi
# fi
#
# # Block SQL instance restart without confirmation
# if echo "$COMMAND" | grep -iE "gcloud\s+sql\s+instances\s+(restart|stop)" >/dev/null; then
#     if echo "$COMMAND" | grep -iE "(TODO-your-prod-db|prod)" >/dev/null; then
#         block_command "Restart/stop of the production database requires manual confirmation."
#     fi
# fi
#
# # Warn on firewall changes
# if echo "$COMMAND" | grep -iE "gcloud\s+compute\s+firewall-rules\s+(delete|update)" >/dev/null; then
#     warn_command "Firewall changes can affect access to production. Double-check the rules."
# fi
#
# # Block deletion of critical secrets
# if echo "$COMMAND" | grep -iE "gcloud\s+secrets\s+delete" >/dev/null; then
#     if echo "$COMMAND" | grep -iE "(JWT|DB_PASSWORD|TODO-critical-secret)" >/dev/null; then
#         block_command "Deleting critical secrets is forbidden. This breaks production."
#     fi
# fi

# ============================================================================
# EXAMPLE: SUPABASE / EXPO EAS SAFETY (uncomment and adapt if you use them)
# ============================================================================

# # Block db reset against a linked (remote) project
# if echo "$COMMAND" | grep -E "supabase\s+db\s+reset" >/dev/null; then
#     if echo "$COMMAND" | grep -E "\-\-linked" >/dev/null; then
#         block_command "supabase db reset --linked wipes the REMOTE database. Forbidden via automation."
#     fi
# fi
#
# # Block deletion of Supabase projects
# if echo "$COMMAND" | grep -E "supabase\s+projects\s+delete" >/dev/null; then
#     block_command "Deleting Supabase projects is forbidden via automation."
# fi
#
# # Warn on destructive remote operations
# if echo "$COMMAND" | grep -E "supabase\s+functions\s+delete" >/dev/null; then
#     warn_command "Deleting an Edge Function — verify nothing in production calls it."
# fi
# if echo "$COMMAND" | grep -E "supabase\s+secrets\s+unset" >/dev/null; then
#     warn_command "Removing a Supabase secret can break production functions. Double-check."
# fi
# if echo "$COMMAND" | grep -E "supabase\s+db\s+push" >/dev/null; then
#     warn_command "supabase db push changes the remote schema. Make sure the migration is reviewed."
# fi
#
# # Block app store submission via automation
# if echo "$COMMAND" | grep -E "eas\s+submit" >/dev/null; then
#     block_command "eas submit publishes to app stores. Requires a manual decision."
# fi
# if echo "$COMMAND" | grep -E "eas\s+build.*--auto-submit" >/dev/null; then
#     block_command "eas build --auto-submit publishes to app stores. Run the build without --auto-submit."
# fi

# ============================================================================
# OK — command approved
# ============================================================================

exit 0
