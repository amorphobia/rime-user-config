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
CONTEXT=0
WORD=""
WEIGHT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK=1
            shift
            ;;
        --context|-c)
            CONTEXT=1
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [options] <phrase> [weight]"
            echo ""
            echo "Calculate encoding for a phrase and output a line ready to"
            echo "add to cizu_append.txt."
            echo ""
            echo "Options:"
            echo "  --check     Check whether the phrase already exists upstream"
            echo "              or in cizu_append.txt"
            echo "  --context   Show same-yinma entries from upstream and append"
            echo "              to help determine the right weight"
            echo "  phrase      The phrase to calculate encoding for"
            echo "  weight      Optional weight (default: 850)"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") 胜在"
            echo "  $(basename "$0") 子模块 980"
            echo "  $(basename "$0") --check 胜在"
            echo "  $(basename "$0") --context 受话器"
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
    WEIGHT="850"
fi

if ! [[ "${WEIGHT}" =~ ^[0-9]+$ ]]; then
    echo "Error: Weight must be a number: ${WEIGHT}" >&2
    exit 1
fi

# Delegate encoding calculation to Python for proper UTF-8 handling
PYTHONIOENCODING=utf-8 python3 -c "
import sys, itertools
try:
    sys.stderr.reconfigure(encoding='utf-8')
except: pass

danzi_path = '${DANZI_WIN}'
raw_path = '${RAW_DICT_WIN}'
append_path = '${APPEND_WIN}'
word = '${WORD}'
weight = '${WEIGHT}'
check = ${CHECK}
context = ${CONTEXT}

# --- Lookup: char -> {yinma: xingma_first} ---
# Collect ALL yinma variants (飞键 + 多音字). Keep longest code per yinma.
lookup = {}  # char -> {yinma: (xingma_first, code_len)}
with open(danzi_path, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if '\t' not in line: continue
        char, code = line.split('\t', 1)
        code = code.split()[0]
        if len(code) < 2: continue
        yin, xing = code[:2], code[2:3] if len(code) > 2 else ''
        if char not in lookup: lookup[char] = {}
        prev = lookup[char].get(yin)
        if prev is None or len(code) > prev[1]:
            lookup[char][yin] = (xing, len(code))

# --- Per-char options: list of (yinma, xingma) tuples ---
char_opts = []
for char in word:
    if char not in lookup:
        print(f'ERROR: \"{char}\" not in danzi.', file=sys.stderr); sys.exit(1)
    opts = [(y, lookup[char][y][0]) for y in sorted(lookup[char].keys())]
    char_opts.append(opts)

# --- Warn if any char has multiple yinmas ---
extra = False
for i, char in enumerate(word):
    opts = char_opts[i]
    if len(opts) > 1:
        extra = True
        yins = [y for y, _ in opts]
        # Heuristic label: same letter except F/Q, J/W, or M/X -> hint 飞键
        hint = ''
        for a in yins:
            for b in yins:
                if a >= b: continue
                if len(a) == 2 and len(b) == 2:
                    if a[0] != b[0] and a[1] == b[1] and {a[0], b[0]} <= set('fq'):
                        hint = ' (可能 zh 飞键 F/Q)'; break
                    if a[0] != b[0] and a[1] == b[1] and {a[0], b[0]} <= set('jw'):
                        hint = ' (可能 ch 飞键 J/W)'; break
                    if a[0] == b[0] and a[1] != b[1] and {a[1], b[1]} <= set('mx'):
                        hint = ' (可能 uang 飞键 M/X)'; break
        tag = hint if hint else ' (可能多音字)'
        print(f'NOTE: \"{char}\" has multiple yinmas: {\" \".join(yins)}{tag}', file=sys.stderr)

if extra:
    print(file=sys.stderr)

# --- Cartesian product ---
combos = list(itertools.product(*char_opts))
nc = len(char_opts)

# Check duplicates
if check:
    for combo in combos:
        yins = [c[0] for c in combo]
        if nc == 2: py = yins[0] + yins[1]
        elif nc == 3: py = ''.join(y[:1] for y in yins)
        else: py = ''.join(y[:1] for y in yins)[:4]
        for path, label in [(raw_path, 'upstream'), (append_path, 'cizu_append')]:
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    for line in f:
                        p = line.strip().split('\t')
                        if len(p) >= 2 and p[0] == word and p[1] == py:
                            print(f'WARNING: \"{word}\" ({py}) already in {label}!', file=sys.stderr)
            except: pass

# Context
if context:
    ctx_seen = set()
    for combo in combos:
        yins = [c[0] for c in combo]; xings = [c[1] for c in combo]
        if nc == 2: py, px = yins[0]+yins[1], xings[0]+xings[1]
        elif nc == 3: py, px = ''.join(y[:1] for y in yins), ''.join(x[:1] for x in xings)
        else: py, px = ''.join(y[:1] for y in yins)[:4], (xings[0][:1] if xings[0] else '')+(xings[1][:1] if len(xings)>1 else '')
        entries = []
        for path, src in [(raw_path, 'upstream'), (append_path, 'append')]:
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    for line in f:
                        p = line.strip().split('\t')
                        if len(p) >= 4 and p[1] == py:
                            entries.append((p[0], p[2], int(p[3]), src))
            except: pass
        key = (py, px)
        if key in ctx_seen: continue
        ctx_seen.add(key)
        entries.sort(key=lambda e: (-e[2], e[1]))
        print(f'Context for {py}:', file=sys.stderr)
        if entries:
            entries.append((word, px, int(weight), 'new'))
            entries.sort(key=lambda e: (-e[2], e[1]))
            for w, xm, wt, src in entries:
                m = ' <= NEW' if src == 'new' else ''
                s = 'NEW' if src == 'new' else src
                print(f'  {wt:>4}  {w}\t{py}\t{xm}  ({s}){m}', file=sys.stderr)
        else:
            print(f'  (first entry for {py})', file=sys.stderr)
        print(file=sys.stderr)

# Output (deduplicated)
seen = set()
for combo in combos:
    yins = [c[0] for c in combo]; xings = [c[1] for c in combo]
    if nc == 2: py, px = yins[0]+yins[1], xings[0]+xings[1]
    elif nc == 3: py, px = ''.join(y[:1] for y in yins), ''.join(x[:1] for x in xings)
    else: py, px = ''.join(y[:1] for y in yins)[:4], (xings[0][:1] if xings[0] else '')+(xings[1][:1] if len(xings)>1 else '')
    key = (py, px)
    if key not in seen:
        seen.add(key)
        print(f'{word}\t{py}\t{px}\t{weight}')
"
