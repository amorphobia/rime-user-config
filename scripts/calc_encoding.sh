#!/usr/bin/env bash
# encoding: utf-8

# Calculate phrase encoding for cizu_append.txt
# Copyright (C) 2026  Xuesong Peng <pengxuesong.cn@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Locate upstream jiandao repo
if [[ -n "${JIANDOO_DIR}" ]]; then
    JIANDOO="${JIANDOO_DIR}"
elif [[ -d "${REPO_DIR}/../rime-jiandao" ]]; then
    JIANDOO="$(cd "${REPO_DIR}/../rime-jiandao" && pwd)"
else
    echo "Error: Cannot find rime-jiandao repo." >&2
    echo "  Clone it first: git clone https://github.com/amorphobia/rime-jiandao" >&2
    echo "  Or set JIANDOO_DIR env var to its path." >&2
    exit 1
fi

DANZI="${JIANDOO}/dicts/01.danzi.txt"
RAW_DICT="${JIANDOO}/dicts/cizu_raw.txt"
APPEND="${REPO_DIR}/dicts/cizu_append.txt"

# Convert to Windows paths with forward slashes for Python compatibility
if command -v cygpath &>/dev/null; then
    DANZI_WIN="$(cygpath -w "${DANZI}" | sed 's|\\|/|g')"
    RAW_DICT_WIN="$(cygpath -w "${RAW_DICT}" | sed 's|\\|/|g')"
    APPEND_WIN="$(cygpath -w "${APPEND}" | sed 's|\\|/|g')"
else
    DANZI_WIN="${DANZI}"
    RAW_DICT_WIN="${RAW_DICT}"
    APPEND_WIN="${APPEND}"
fi

if [[ ! -f "${DANZI}" ]]; then
    echo "Error: Cannot find ${DANZI}" >&2
    exit 1
fi

# Parse arguments
CHECK=0
WORD=""
WEIGHT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK=1
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--check] <phrase> [weight]"
            echo ""
            echo "Calculate encoding for a phrase and output a line ready to"
            echo "add to cizu_append.txt."
            echo ""
            echo "  --check    Check whether the phrase already exists upstream"
            echo "             or in cizu_append.txt"
            echo "  phrase     The phrase to calculate encoding for"
            echo "  weight     Optional weight (default: 950)"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") 胜在"
            echo "  $(basename "$0") 子模块 980"
            echo "  $(basename "$0") --check 胜在"
            exit 0
            ;;
        *)
            if [[ -z "${WORD}" ]]; then
                WORD="$1"
            elif [[ -z "${WEIGHT}" ]]; then
                WEIGHT="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "${WORD}" ]]; then
    echo "Error: No phrase specified." >&2
    exit 1
fi

if [[ -z "${WEIGHT}" ]]; then
    WEIGHT="950"
fi

if ! [[ "${WEIGHT}" =~ ^[0-9]+$ ]]; then
    echo "Error: Weight must be a number: ${WEIGHT}" >&2
    exit 1
fi

# Delegate encoding calculation to Python for proper UTF-8 handling
python3 -c "
import sys

danzi_path = '${DANZI_WIN}'
raw_path = '${RAW_DICT_WIN}'
append_path = '${APPEND_WIN}'
word = '${WORD}'
weight = '${WEIGHT}'
check = ${CHECK}

# Build lookup from danzi: char -> (音码, 形码首码)
# Use the longest code for each character
lookup = {}
with open(danzi_path, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if '\t' not in line:
            continue
        char, code = line.split('\t', 1)
        code = code.split()[0]  # remove any comment
        if len(code) < 2:
            continue  # short code, skip
        yinma = code[:2]
        xingma_first = code[2:3] if len(code) > 2 else ''
        prev = lookup.get(char)
        if prev is None or len(code) > len(prev[2]):
            lookup[char] = (yinma, xingma_first, code)

# Check for duplicates
if check:
    found = False
    with open(raw_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith(word + '\t'):
                print(f'WARNING: \"{word}\" already exists in cizu_raw.txt (upstream)!', file=sys.stderr)
                found = True
                break
    with open(append_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith(word + '\t'):
                print(f'WARNING: \"{word}\" already exists in cizu_append.txt!', file=sys.stderr)
                found = True
                break

# Get encoding for each character
yinmas = []
xingmas = []
for char in word:
    if char not in lookup:
        print(f'ERROR: Cannot find character \"{char}\" in danzi.', file=sys.stderr)
        sys.exit(1)
    y, x, _ = lookup[char]
    yinmas.append(y)
    xingmas.append(x)

num = len(yinmas)

if num == 2:
    # 二字词: 两字音码各取 2 码, 两字形码各取第 1 码
    phrase_yin = yinmas[0] + yinmas[1]
    phrase_xing = xingmas[0] + xingmas[1]
elif num == 3:
    # 三字词: 三字音码各取首码, 三字形码各取首码
    phrase_yin = ''.join(y[:1] for y in yinmas)
    phrase_xing = ''.join(x[:1] for x in xingmas)
else:
    # 四字及以上: 四字各取音码首码
    phrase_yin = ''.join(y[:1] for y in yinmas)[:4]
    # 前两字形码首码
    phrase_xing = (xingmas[0][:1] if xingmas[0] else '') + (xingmas[1][:1] if len(xingmas) > 1 else '')

print(f'{word}\t{phrase_yin}\t{phrase_xing}\t{weight}')
"
