#!/bin/bash

# Find all .oracleGeneral.zst files under /mntData2/data/oracleReuse/ and generate cachesim commands
find /s3/cache_datasets/cache_dataset_lcs/alibaba -name "*.lcs.zst" -type f | while read -r file; do
    size=$(stat -c%s "$file")
    if [ "$size" -gt $((1 * 1024 * 1024 * 1024)) ]; then
        continue
    fi
    # min_dram_gb = 30x file size in GB, minimum 2 GB
    size_gb=$(echo "scale=2; $size / 1073741824" | bc)
    min_dram_gb=$(echo "scale=0; $size * 30 / 1073741824 / 1" | bc)
    if [ "$min_dram_gb" -lt 20 ]; then
        min_dram_gb=20
    fi
    absolute_path=$(realpath "$file")
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms fifo,lru"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms clock,lfu"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms random,car"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms arc,lirs"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms belady,sieve"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms lecar,lhd"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms hyperbolic,gdsf"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms tinyLFU,twoq"
    echo "shell:4:${min_dram_gb}:2:python3 /users/YJZheng/distComp/generate_MRC.py --tracepath  $absolute_path --xmax 1 --algorithms s3fifo,cacheus"
done > ./task