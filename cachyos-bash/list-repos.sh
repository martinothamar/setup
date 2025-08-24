#!/bin/bash

readarray -t repos < <(pacman-conf -l)
echo "Repos: ${repos[*]}" | xargs

mkdir -p repos/

for i in "${repos[@]}" ; do
    paclist "${i}" | awk '{print $1}' > "repos/${i}.lst"
done
