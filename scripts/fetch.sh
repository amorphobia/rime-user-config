#!/usr/bin/env bash
# encoding: utf-8

# Fetch Schemas
# Copyright (C) 2023  Fu Xiao <https://github.com/imfuxiao>
# Copyright (C) 2023  Xuesong Peng <pengxuesong.cn@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Original idea & script (GPL-3.0 license) can be found at
# https://github.com/imfuxiao/HamsterInputSchemas/blob/520ff76aada26b3c05851ba6feb42c72a5558021/build.sh

set -e

VERSION="master"

ARGS=$(getopt -o v: --long setver: -n "$(basename $0)" -- "$@")
if [[ $? -ne 0 ]]
then
    exit 1
fi

eval set -- "${ARGS}"

while true
do
    case "$1" in
        -v | --setver )
            VERSION=$2
            shift 2
            ;;
        -- )
            shift
            break
            ;;
        * )
            exit 1
            ;;
    esac
done

WORK=$(pwd)
DICTS=${WORK}/dicts
SCHEMAS=${WORK}/schemas
XIAOXIAO=${WORK}/xiaoxiao

rm -rf ${SCHEMAS}

mkdir -p ${SCHEMAS}/lua
mkdir -p ${SCHEMAS}/opencc
mkdir ${XIAOXIAO}

# 🌟️星空键道
# https://github.com/amorphobia/rime-jiandao
rm -rf jiandao && \
git clone --depth 1 https://github.com/amorphobia/rime-jiandao jiandao && (
    cd jiandao && \
    cat ${DICTS}/danzi_append.txt >> dicts/01.danzi.txt && \
    cat ${DICTS}/buchong_append.txt >> dicts/04.buchong.txt && \
    bash scripts/make_dicts.sh --append ${DICTS}/cizu_append.txt --delete ${DICTS}/cizu_delete.txt --modify ${DICTS}/cizu_modify.txt --version ${VERSION} --deweight && \
    rm schema/recipe.yaml schema/rime.lua
) && \
cp -r jiandao/schema/* ${SCHEMAS}/ && \
cp -r jiandao/xiaoxiao/* ${XIAOXIAO}/ && \
echo "fetch Jiandao done."

# 袖珍简化字拼音
# https://github.com/rime/rime-pinyin-simp
rm -rf simp && \
git clone --depth 1 https://github.com/rime/rime-pinyin-simp simp && \
cp simp/pinyin_simp.* ${SCHEMAS}/ && \
echo "fetch pinyin-simp done."

# 日本語
# https://github.com/gkovacs/rime-japanese
rm -rf japanese && \
git clone --depth 1 https://github.com/gkovacs/rime-japanese japanese && (
    cd japanese && \
    sed -i '/import_tables/,/^\.\.\.$/{/^\./!d}' japanese.dict.yaml && \
    for dict in mozc jmdict kana
    do
        sed '0,/^\.\.\.$/d' japanese.${dict}.dict.yaml | awk '!seen[$1,$2]++' >> japanese.dict.yaml && \
        rm japanese.${dict}.dict.yaml
    done
) && \
cp japanese/*.yaml ${SCHEMAS}/ && \
echo "fetch japanese done."

# 蜀拼-重慶
# https://github.com/Papnas/shupin
rm -rf shupin && \
git clone --depth 1 https://github.com/Papnas/shupin && \
cp shupin/*.dict.yaml ${SCHEMAS}/ && \
cp shupin/shupin_congqin.schema.yaml ${SCHEMAS}/ && \
echo "fetch shupin-congqin done."

# 繪文字
# https://github.com/rime/rime-emoji
if command -v opencc &> /dev/null
then
    echo "$(opencc --version)"
    rm -rf emoji
    git clone --depth 1 https://github.com/rime/rime-emoji emoji
    opencc -c t2s.json -i emoji/opencc/emoji_category.txt | awk '!seen[$1]++' > ${SCHEMAS}/opencc/emoji_category.txt
    opencc -c t2s.json -i emoji/opencc/emoji_word.txt | awk '!seen[$1]++' > ${SCHEMAS}/opencc/emoji_word.txt
    # https://github.com/rime/rime-emoji/issues/48
    sed -i 's/鼔/鼓/g' ${SCHEMAS}/opencc/emoji_word.txt
    cp emoji/opencc/emoji.json ${SCHEMAS}/opencc/
    echo "fetch emoji done."
fi

# ➕️绘文字加
# https://github.com/amorphobia/rime-emoji-plus
rm -rf emoji_plus && \
git clone --depth 1 https://github.com/amorphobia/rime-emoji-plus emoji_plus && \
cp emoji_plus/opencc/* ${SCHEMAS}/opencc/ && \
echo "fetch emoji-plus done."

# OpenCC 简繁转换之通用规范汉字标准
# https://github.com/amorphobia/opencc-tonggui
rm -rf tonggui && \
git clone --depth 1 https://github.com/amorphobia/opencc-tonggui tonggui && (
    cd tonggui && \
    if command -v opencc &> /dev/null
    then
        make
    fi
) && \
cp tonggui/opencc/* ${SCHEMAS}/opencc/ && \
echo "fetch tonggui done."

# OpenCC 转换之焱暒妏
# https://github.com/amorphobia/opencc-martian
rm -rf martian && \
git clone --depth 1 https://github.com/amorphobia/opencc-martian martian && (
    cd martian && \
    if command -v opencc &> /dev/null
    then
        make
    fi
) && \
cp martian/opencc/* ${SCHEMAS}/opencc/ && \
echo "fetch martian done."
