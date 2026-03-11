#!/usr/bin/env bash
# check_specific_file.sh
# Usage: ./check_specific_file.sh <filename>
# Searches for /users/YJZheng/libCacheSim/_build/result/<filename> on all nodes,
# prints which node has it and the line count (wc -l).

if [ -z "$1" ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

FILENAME="$1"
FILEPATH="/users/YJZheng/libCacheSim/_build/result/${FILENAME}"

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

found=()
missing=()

for node in "${NODES[@]}"; do
    result=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$node" \
        "[ -f '$FILEPATH' ] && wc -l < '$FILEPATH'" 2>/dev/null)
    if [ -n "$result" ]; then
        echo -e "  ${GREEN}✓${NC} $node  lines: $result"
        found+=("$node")
    else
        echo -e "  ${RED}✗${NC} $node"
        missing+=("$node")
    fi
done

echo ""
echo -e "${GREEN}[INFO]${NC} Found on : ${#found[@]} node(s)"
echo -e "${RED}[INFO]${NC} Missing  : ${#missing[@]} node(s)"
