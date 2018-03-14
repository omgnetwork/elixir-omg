#!/bin/bash
FLAGS="--abi --opcodes --hashes --bin --pretty-json"
OUTPUT="build"
INPUT_FILE="RootChain/RootChain.sol"

#out put color
NC='\033[0m'
Red='\033[0;31m'
Green='\033[0;32m'
Brown='\033[0;33m'
Cyan='\033[0;36m'
Purple='\033[0;35m'
Blue='\033[0;34m'

#removeing everything from the output folder
echo -e ${Red}rm${NC} ${OUTPUT}/*
echo --------------------------------------------------------------
rm $OUTPUT/*
echo -e ${Purple}==============================================================${NC}



#create map of import
echo -e "${Blue}map import:${NC}"
MAP_NAMES=""
prefix_path="$(pwd)"
for path in **/*.sol 
do 
	file_name="$(basename $path)"
	full_path="${prefix_path}/${path}"
	echo -e "${Brown}${file_name}${NC} : ${Cyan}${full_path}${NC}" 
	MAP_NAMES="$MAP_NAMES ${file_name}=${full_path} "
done
echo -e ${Purple}==============================================================${NC}



echo -e ${Green}solc${NC} $FLAGS -o $OUTPUT $MAP_NAMES $INPUT_FILE
echo --------------------------------------------------------------
solc $FLAGS -o $OUTPUT $MAP_NAMES $INPUT_FILE

