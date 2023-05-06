#!/usr/bin/env bash
# encoding: utf-8
set -e

SCHEMAS=schemas

rm -rf ${SCHEMAS}

mkdir -p ${SCHEMAS}/lua
mkdir -p ${SCHEMAS}/opencc

# ⭐星空键道
# https://github.com/xkinput/Rime_JD
rm -rf jiandao && \
git clone --depth 1 https://github.com/xkinput/Rime_JD jiandao --branch plum && \
cp jiandao/xkjd6.*.yaml ${SCHEMAS}/ && \
cp jiandao/lua/* ${SCHEMAS}/lua/ && \
cp jiandao/opencc/EN2en* ${SCHEMAS}/opencc/ && \
cp jiandao/rime.lua ${SCHEMAS}/

# 🍀四叶草
# https://github.com/fkxxyz/rime-cloverpinyin
clover_ver="1.1.4"
clover_zip="clover.schema-${clover_ver}.zip"
clover_url="https://github.com/fkxxyz/rime-cloverpinyin/releases/download/${clover_ver}/${clover_zip}"
rm -rf clover && mkdir -p clover && (
    cd clover
    curl -LO "${clover_url}"
    unzip "${clover_zip}" -d .
    rm -rf ${clover_zip}
) && \
cp clover/*.yaml ${SCHEMAS}/ && \
cp clover/opencc/symbol* ${SCHEMAS}/opencc/

# 🇯🇵日本語
# https://github.com/gkovacs/rime-japanese
rm -rf japanese && \
git clone --depth 1 https://github.com/gkovacs/rime-japanese japanese && \
cp japanese/*.yaml ${SCHEMAS}/

# 🍲蜀拼-重庆
# https://github.com/Papnas/shupin
rm -rf shupin && \
git clone --depth 1 https://github.com/Papnas/shupin && \
cp shupin/*.dict.yaml ${SCHEMAS}/ && \
cp shupin/shupin_congqin.schema.yaml ${SCHEMAS}/

# 😂绘文字
# https://github.com/rime/rime-emoji
if command -v opencc &> /dev/null
then
    rm -rf emoji
    git clone --depth 1 https://github.com/rime/rime-emoji emoji
    opencc -c t2s.json -i emoji/opencc/emoji_category.txt | awk '!seen[$1]++' > emoji/opencc/emoji_category.txt
    opencc -c t2s.json -i emoji/opencc/emoji_word.txt | awk '!seen[$1]++' > emoji/opencc/emoji_word.txt
    cp emoji/opencc/* ${SCHEMAS}/opencc/
fi
