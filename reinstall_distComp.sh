#!/usr/bin/env bash
# reinstall_distComp.sh
# For all nodes: delete ~/distComp and re-clone from distComp_runTraces

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

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

successful=()
failed=()

for node in "${NODES[@]}"; do
    echo -e "${GREEN}[INFO]${NC} [$node] Reinstalling distComp..."
    if ! ssh -o StrictHostKeyChecking=accept-new "$node" '
        set -e
        rm -rf ~/distComp
        git clone https://github.com/SeverinaZheng/distComp_runTraces.git ~/distComp
    '; then
        echo -e "${RED}[ERROR]${NC} [$node] failed" >&2
        failed+=("$node")
        continue
    fi
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

echo -e "${GREEN}[INFO]${NC} All nodes reinstalled."
