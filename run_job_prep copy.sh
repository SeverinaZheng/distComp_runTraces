#!/usr/bin/env bash
# run_job_prep.sh
# 1. Copy generate_MRC.py to all nodes' /users/YJZheng/distComp
# 2. On each node: activate the venv and pip install matplotlib
# 3. On each node: activate the venv and pip install redis psutil

set -euo pipefail

NODES=(
    node0  node1  node2  node3
    node4  node5  node6  node7
    node8  node9  node10 node11
    node12 node13 node14 node15
    node16 node17 node18 node19
    node20 node21 node22 node23
    node24 node25 node26 node27
    node28 node29 node30 node31
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SRC="$SCRIPT_DIR/generate_MRC.py"
REMOTE_DIR="/users/YJZheng/distComp"
VENV="$HOME/.parallel-ssh-venv"

if [ ! -f "$SRC" ]; then
    echo "[ERROR] $SRC not found" >&2
    exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

successful=()
failed=()

for node in "${NODES[@]}"; do
    echo -e "${GREEN}[INFO]${NC} [$node] Copying generate_MRC.py..."
    if ! scp -o StrictHostKeyChecking=accept-new "$SRC" "${node}:${REMOTE_DIR}/generate_MRC.py"; then
        echo -e "${RED}[ERROR]${NC} [$node] scp failed" >&2
        failed+=("$node")
        continue
    fi

    echo -e "${GREEN}[INFO]${NC} [$node] Installing matplotlib in venv..."
    if ! ssh -o StrictHostKeyChecking=accept-new "$node" \
        "source ${VENV}/bin/activate && pip install --quiet matplotlib"; then
        echo -e "${RED}[ERROR]${NC} [$node] pip install failed" >&2
        failed+=("$node")
        continue
    fi

    echo -e "${GREEN}[INFO]${NC} [$node] Installing redis psutil in venv..."
    if ! ssh -o StrictHostKeyChecking=accept-new "$node" \
        "source ${VENV}/bin/activate && pip install --quiet redis psutil"; then
        echo -e "${RED}[ERROR]${NC} [$node] pip install failed" >&2
        failed+=("$node")
        continue
    fi

    echo -e "${GREEN}[INFO]${NC} [$node] Copying conf.json..."
    if ! scp -o StrictHostKeyChecking=accept-new "${REMOTE_DIR}/conf.json" "${node}:${REMOTE_DIR}/conf.json"; then
        echo -e "${RED}[ERROR]${NC} [$node] conf.json copy failed" >&2
        failed+=("$node")
        continue
    fi

    echo -e "${GREEN}[INFO]${NC} [$node] Removing libCacheSim result dir if exists..."
    ssh -o StrictHostKeyChecking=accept-new "$node" \
        "rm -rf /users/YJZheng/libCacheSim/_build/result" || true

    echo -e "${GREEN}[INFO]${NC} [$node] Done."
    successful+=("$node")
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

echo -e "${GREEN}[INFO]${NC} All nodes ready."
