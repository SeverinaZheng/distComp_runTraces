#!/bin/bash

# Find all .oracleGeneral.zst files under /mntData2/data/oracleReuse/ and generate cachesim commands
find /mntData2/data/oracleReuse/ -name "*.oracleGeneral.zst" -type f | while read -r file; do
    absolute_path=$(realpath "$file")
    echo "shell:4:2:2:/users/YJZheng/libCacheSim/_build/bin/cachesim $absolute_path oracleGeneral fifo,lru,clock,lfu,random,car,arc,lirs 0.001,0.01,0.1 --ignore-obj-size 0"
    echo "shell:4:2:2:/users/YJZheng/libCacheSim/_build/bin/cachesim $absolute_path oracleGeneral belady,sieve,lecar 0.001,0.01,0.1 --ignore-obj-size 0"
    echo "shell:4:2:2:/users/YJZheng/libCacheSim/_build/bin/cachesim $absolute_path oracleGeneral lhd,hyperbolic,gdsf,wtinyLFU,twoq,slru,s3fifo 0.001,0.01,0.1 --ignore-obj-size 0"
done > ./task