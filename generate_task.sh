#!/bin/bash

# Find all .oracleGeneral.zst files under /mntData2/data/oracleReuse/ and generate cachesim commands
find /s3/cache_datasets/cache_dataset_lcs/alibaba -name "*.lcs.zst" -type f | while read -r file; do
    size=$(stat -c%s "$file")
    if [ "$size" -gt $((5 * 1024 * 1024 * 1024)) ]; then
        continue
    fi
    absolute_path=$(realpath "$file")
    echo "shell:4:2:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms fifo,lru,clock,lfu,random,car,arc,lirs"
    echo "shell:4:2:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms belady,sieve,lecar,lhd,hyperbolic,gdsf,wtinyLFU,twoq,s3fifo"
done > ./task