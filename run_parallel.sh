#!/bin/bash

set -e

INPUT_FILE="input/archivo.dat"
CHUNKS_DIR="chunks"
OUTPUT_CHUNKS_DIR="output_chunks"
LOGS_DIR="logs"
FILES_LIST="files.txt"

N_JOBS=4
N_HEADER_LINES=0

mkdir -p "$OUTPUT_CHUNKS_DIR" "$LOGS_DIR"

find "$CHUNKS_DIR" -name "chunk_*.dat" | sort > "$FILES_LIST"

parallel -j "$N_JOBS" --joblog "$LOGS_DIR/joblog.txt" \
'matlab -singleCompThread -nodisplay -nosplash -batch "SA_RunTravis_parallel('\'{}\'')"' \
:::: "$FILES_LIST"

matlab -singleCompThread -nodisplay -nosplash -batch \
"merge_ana_chunks('$INPUT_FILE','$OUTPUT_CHUNKS_DIR','.',${N_HEADER_LINES})"
