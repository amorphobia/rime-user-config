#!/usr/bin/env bash
# encoding: utf-8

# Batch insert entries into a sorted dictionary file
# Copyright (C) 2026  Xuesong Peng <pengxuesong.cn@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Insert multiple entries into a file in a single invocation.
# Entries are read from stdin and inserted after the specified line number.
# Processes from bottom to top, so line numbers of pending entries stay valid.
#
# Usage:
#   bash scripts/insert_entries.sh <target_file>
#
# Stdin format (one entry per line, TAB-separated):
#   <after_line_number>	<word>	<yinma>	<xingma>	<weight>
#
# Example:
#   echo '8135	长轮询	jlx	uvo	850
#   3169	手敲	edqc	io	850' | bash scripts/insert_entries.sh dicts/cizu_append.txt

set -e

target="$1"

if [[ ! -f "$target" ]]; then
    echo "Error: Target file not found: $target" >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <target_file>" >&2
    echo "Reads entries from stdin: after_line<TAB>word<TAB>yinma<TAB>xingma<TAB>weight" >&2
    exit 1
fi

# Collect all entries from stdin
entries_file=$(mktemp)
trap "rm -f $entries_file" EXIT

count=0
while IFS=$'\t' read -r lineno word yinma xingma weight; do
    # Skip empty lines
    [[ -z "$lineno" ]] && continue
    # Validate line number
    if ! [[ "$lineno" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid line number: $lineno" >&2
        rm -f "$entries_file"
        exit 1
    fi
    printf '%d\t%s\t%s\t%s\t%s\n' "$lineno" "$word" "$yinma" "$xingma" "$weight" >> "$entries_file"
    count=$((count + 1))
done

if [[ $count -eq 0 ]]; then
    echo "Error: No entries provided on stdin." >&2
    rm -f "$entries_file"
    exit 1
fi

# Sort by line number descending — insert from bottom to top
# so line numbers above the insertion point remain valid
sort -s -t$'\t' -k1,1nr "$entries_file" -o "$entries_file"

# Apply each insertion.
# For consecutive entries with the same after_line, the actual target
# line is offset by the number of same-line entries already inserted,
# so they stack in input order (first in input = first in output).
prev_lineno=""
same_offset=0
while IFS=$'\t' read -r lineno word yinma xingma weight; do
    entry="${word}	${yinma}	${xingma}	${weight}"
    if [[ "$lineno" == "$prev_lineno" ]]; then
        same_offset=$((same_offset + 1))
    else
        same_offset=0
    fi
    if [[ "$lineno" == "0" ]]; then
        # after_line 0 = 插到文件开头；同基线多条按输入顺序堆叠
        if [[ "$same_offset" == "0" ]]; then
            sed -i "1i\\
${entry}" "$target"
        else
            sed -i "${same_offset}a\\
${entry}" "$target"
        fi
    else
        actual_lineno=$((lineno + same_offset))
        sed -i "${actual_lineno}a\\
${entry}" "$target"
    fi
    prev_lineno="$lineno"
done < "$entries_file"

echo "Inserted $count entries into $(basename "$target")." >&2
