#!/usr/bin/env bash
#
# Instant cleanup script for orphaned VS Code and TRAE processes
#

set -euo pipefail

echo "==========================================="
echo " [1/4] Terminating runaway & zombie processes"
echo "==========================================="

# Kill Trae's Code Knowledge Graph (vector search / embedding) instances
if pgrep -f "ckg_server" > /dev/null; then
    echo "Killing ckg_server processes..."
    pkill -9 -f "ckg_server" || true
else
    echo "No ckg_server processes detected."
fi

# Kill lingering AI agent tool hosts and completion servers
for proc in "ai-agent" "agent-tool-host" "aiserver/cue.js" "trae-helper"; do
    if pgrep -f "$proc" > /dev/null; then
        echo "Killing $proc processes..."
        pkill -9 -f "$proc" || true
    fi
done

# Kill orphaned VS Code / Trae server and node runners
for proc in "vscode-server" "trae-server"; do
    if pgrep -f "$proc" > /dev/null; then
        echo "Killing $proc processes..."
        pkill -9 -f "$proc" || true
    fi
done

# Clean up any lingering background PHP built-in dev servers spawned by the agent
if pgrep -f "php -S 127.0.0.1" > /dev/null; then
    echo "Killing temporary agent PHP test servers..."
    pkill -9 -f "php -S 127.0.0.1" || true
fi

echo "==========================================="
echo " [2/4] Purging vector databases and caches"
echo "==========================================="

# Remove the SQLite vector embeddings database that triggers multi-port ckg loops
if [ -d "/root/.trae-server/ckg_server" ]; then
    echo "Removing /root/.trae-server/ckg_server..."
    rm -rf /root/.trae-server/ckg_server
fi

# Clear manager logs and session crash dumps
if [ -d "/root/.trae-server/manager-logs" ]; then
    echo "Clearing Trae manager logs..."
    rm -rf /root/.trae-server/manager-logs/*
fi

# Remove agent temporary snapshots
rm -rf /tmp/trae-agent-toolhost-* 2>/dev/null || true
rm -rf /root/.trae/toolhost/native-runcommand-snapshots/* 2>/dev/null || true

# Clear stale socket handles in /run/user/0
rm -f /run/user/0/vscode-git-*.sock 2>/dev/null || true

echo "==========================================="
echo " [3/4] Purging old unused server binaries"
echo "==========================================="

# Remove outdated binary directories, keeping disk clean
# Trae downloads a clean copy of the matching client version upon reconnection
if [ -d "/root/.trae-server/bin" ]; then
    echo "Cleaning legacy server builds in /root/.trae-server/bin..."
    rm -rf /root/.trae-server/bin/*
fi

# Clean legacy vscode-server if present
if [ -d "/root/.vscode-server" ]; then
    echo "Purging old .vscode-server cache..."
    rm -rf /root/.vscode-server
fi

echo "==========================================="
echo " [4/4] Verification"
echo "==========================================="

REMAINING=$(pgrep -f "ckg_server|trae-server|vscode-server" | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo "SUCCESS: All target processes killed and caches cleared."
else
    echo "WARNING: $REMAINING processes still detected. Check with: ps aux | grep -E 'trae-server|ckg_server'"
fi

echo ""
echo "Current System Load:"
uptime
