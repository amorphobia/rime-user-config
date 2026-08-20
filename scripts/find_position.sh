#!/usr/bin/env bash
# encoding: utf-8

# Find the insertion position(s) of new entries in a sorted dictionary file.
# Copyright (C) 2026  Xuesong Peng <pengxuesong.cn@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Usage:
#   单条模式（定位一个条目，输出人类可读结果）:
#     bash scripts/find_position.sh <file> <音码> [形码] [权重] [次要权重]
#
#   批量模式（从 stdin 读取多条，输出可直接喂给 insert_entries.sh 的行）:
#     printf '词\t音码\t形码\t权重\t[次要权重]\n...' | bash scripts/find_position.sh <file>
#   批量模式每行输出: after_line<TAB>词<TAB>音码<TAB>形码<TAB>权重
#   形码/权重可省略（如 cizu_modify.txt 的增量条目），此时只按音码边界定位。
#
# 文件排序规则（与 cizu_append.txt 一致）:
#   音码 → 权重降序 → 次要权重降序 → 形码
#
# Examples:
#   bash scripts/find_position.sh dicts/cizu_append.txt enwd oa 850
#   printf '斑竹\tbfqj\tvu\t850\n' | bash scripts/find_position.sh dicts/cizu_append.txt
#   printf '玉兔毫\tyth\t+100\n' | bash scripts/find_position.sh dicts/cizu_modify.txt

set -e

file="$1"
code="${2:-}"

if [[ -z "$file" ]]; then
    echo "Usage: $(basename "$0") <file> [音码 [形码 [权重]]]" >&2
    echo "  单条模式: 传 音码 [形码] [权重] 参数" >&2
    echo "  批量模式: 从 stdin 读 词<TAB>音码<TAB>形码<TAB>权重 行" >&2
    exit 1
fi

tmp=$(mktemp)
trap "rm -f $tmp" EXIT

MODE="batch"
if [[ -n "$code" ]]; then
    MODE="single"
    printf '%s\t%s\t%s\t%s\t%s\n' "-" "$code" "${3:-}" "${4:-}" "${5:-}" > "$tmp"
else
    cat > "$tmp"
fi

awk -F'\t' -v mode="$MODE" '
function better(a_w, a_s, a_x, b_w, b_s, b_x) {
    # 返回 1 表示 a 应排在 b 之前
    # 排序规则：权重降序 → 次要权重降序 → 形码升序
    if (a_w != b_w) return (a_w > b_w)
    if (a_s != b_s) return (a_s > b_s)
    return (a_x < b_x)
}
NR == FNR {
    if ($0 == "") next
    t++
    tword[t] = $1; tcode[t] = $2; txing[t] = $3; tweight[t] = $4; tsub[t] = $5
    next
}
{
    for (i = 1; i <= t; i++) {
        c = $2
        if (c < tcode[i]) {
            prev_nr[i] = FNR; prev_line[i] = $0
        } else if (c == tcode[i]) {
            gc[i]++
            gn[i, gc[i]] = FNR; gl[i, gc[i]] = $0
            gw[i, gc[i]] = $4 + 0; gs[i, gc[i]] = $5 + 0; gx[i, gc[i]] = $3
        } else if (!first_gt[i]) {
            first_gt[i] = FNR; first_gt_line[i] = $0
        }
    }
}
function t_after(a, b) {
    # 返回 1 表示目标 a 应排在目标 b 之后
    # 输出排序：音码 → 权重降序 → 次要权重降序 → 形码升序
    # （与文件排序规则一致，保证同 after_line 的多条按正确组内顺序堆叠）
    if (tcode[a] != tcode[b]) return (tcode[a] > tcode[b])
    wa = tweight[a] + 0; wb = tweight[b] + 0
    if (wa != wb) return (wa < wb)
    sa = tsub[a] + 0; sb = tsub[b] + 0
    if (sa != sb) return (sa < sb)
    return (txing[a] > txing[b])
}
END {
    # 按组内排序规则对目标排序（插入排序，t 通常很小）
    for (i = 1; i <= t; i++) idx[i] = i
    for (i = 2; i <= t; i++) {
        key = idx[i]; j = i - 1
        while (j >= 1 && t_after(idx[j], key)) { idx[j + 1] = idx[j]; j-- }
        idx[j + 1] = key
    }
    for (ii = 1; ii <= t; ii++) {
        i = idx[ii]
        after = prev_nr[i]
        if (tweight[i] != "" && gc[i] > 0) {
            # 组内定位：按 权重降序 → 次要权重降序 → 形码升序
            w = tweight[i] + 0; s = tsub[i] + 0
            pos = gc[i] + 1
            for (j = 1; j <= gc[i]; j++) {
                if (better(w, s, txing[i], gw[i, j], gs[i, j], gx[i, j])) { pos = j; break }
            }
            if (pos > 1) after = gn[i, pos - 1]
        }
        if (mode == "single") {
            if (tweight[i] != "" && gc[i] > 0) {
                printf "after_line: %d（同音码组内第 %d/%d 条）\n", after, pos, gc[i]
                printf "同音码组成员:\n"
                for (j = 1; j <= gc[i]; j++) printf "  %d: %s\n", gn[i, j], gl[i, j]
            } else {
                printf "after_line: %d\n", after
                printf "前一行: %s\n", (prev_nr[i] ? prev_line[i] : "（文件开头）")
                printf "后一行: %s\n", (first_gt[i] ? first_gt_line[i] : "（文件结尾）")
            }
        } else {
            # 批量模式：输出 insert_entries.sh 可直接使用的行
            printf "%d\t%s\t%s\t%s\t%s\n", after, tword[i], tcode[i], txing[i], tweight[i]
            # 上下文输出到 stderr 供核对
            if (prev_nr[i]) printf "  %s[%d] %s\n", tcode[i], prev_nr[i], prev_line[i] > "/dev/stderr"
            if (first_gt[i]) printf "  %s[%d] %s\n", tcode[i], first_gt[i], first_gt_line[i] > "/dev/stderr"
        }
    }
}
' "$tmp" "$file"
