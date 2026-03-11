#!/usr/bin/env bash
# collect_results.sh
# For each node, collect files from ~/libCacheSim/_build/result into
# the local ~/libCacheSim/_build/result directory.
# If a file with the same name already exists locally, append instead of overwrite.

set -euo pipefail

NODES=(
    node1  node2  node3
    node4  node5  node6  node7
    node8  node9  node10 node11
    node12 node13 node14 node15
    node16 node17 node18 node19
    node20 node21 node22 node23
    node24 node25 node26 node27
    node28 node29 node30 node31
)

REMOTE_RESULT_DIR="/users/YJZheng/libCacheSim/_build/result"
LOCAL_RESULT_DIR="$HOME/libCacheSim/_build/result"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create local result directory if it doesn't exist
mkdir -p "$LOCAL_RESULT_DIR"
echo -e "${GREEN}[INFO]${NC} Local result dir: $LOCAL_RESULT_DIR"

successful=()
failed=()

for node in "${NODES[@]}"; do
    echo -e "${GREEN}[INFO]${NC} [$node] Listing remote result files..."

    # List files (not directories) in the remote result dir; skip if missing
    remote_files=$(ssh -o StrictHostKeyChecking=accept-new "$node" \
        "find \"$REMOTE_RESULT_DIR\" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null" || true)

    if [ -z "$remote_files" ]; then
        echo -e "${YELLOW}[WARN]${NC} [$node] No files found in $REMOTE_RESULT_DIR, skipping."
        successful+=("$node")
        continue
    fi

    node_failed=false
    while IFS= read -r filename; do
        [ -z "$filename" ] && continue
        local_file="$LOCAL_RESULT_DIR/$filename"

        if [ -f "$local_file" ]; then
            # File already exists locally — append remote content
            echo -e "${YELLOW}[APPEND]${NC} [$node] $filename exists locally, appending..."
            if ! ssh -o StrictHostKeyChecking=accept-new "$node" \
                "cat \"$REMOTE_RESULT_DIR/$filename\"" >> "$local_file"; then
                echo -e "${RED}[ERROR]${NC} [$node] Failed to append $filename" >&2
                node_failed=true
            fi
        else
            # File does not exist locally — copy it directly
            echo -e "${GREEN}[INFO]${NC} [$node] Copying $filename..."
            if ! scp -o StrictHostKeyChecking=accept-new \
                "${node}:${REMOTE_RESULT_DIR}/${filename}" "$local_file"; then
                echo -e "${RED}[ERROR]${NC} [$node] Failed to copy $filename" >&2
                node_failed=true
            fi
        fi
    done <<< "$remote_files"

    if $node_failed; then
        failed+=("$node")
    else
        successful+=("$node")
    fi
done

echo ""
echo -e "${GREEN}[INFO]${NC} === SUMMARY ==="
echo -e "${GREEN}[INFO]${NC} Success: ${#successful[@]} / ${#NODES[@]}"
for n in "${successful[@]}"; do echo -e "  ${GREEN}✓${NC} $n"; done

if [ ${#failed[@]} -gt 0 ]; then
    echo -e "${RED}[ERROR]${NC} Failed: ${#failed[@]} node(s)"
    for n in "${failed[@]}"; do echo -e "  ${RED}✗${NC} $n"; done
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} All nodes processed."
