#!/usr/bin/env bash
# check_cachesim.sh
# Check which nodes are missing /users/YJZheng/libCacheSim/_build/bin/cachesim

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

BINARY="/users/YJZheng/libCacheSim/_build/bin/cachesim"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

missing=()
present=()

for node in "${NODES[@]}"; do
    if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$node" \
        "test -f '$BINARY'" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $node"
        present+=("$node")
    else
        echo -e "  ${RED}✗${NC} $node  (missing)"
        missing+=("$node")
    fi
done

echo ""
echo -e "${GREEN}[INFO]${NC} Present : ${#present[@]} / ${#NODES[@]}"
echo -e "${RED}[INFO]${NC} Missing : ${#missing[@]} / ${#NODES[@]}"

if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}[INFO]${NC} Nodes missing cachesim:"
    for n in "${missing[@]}"; do echo "  $n"; done
fi
