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
for dict in danzi cizu fuhao buchong lianjie chaojizici wxw
do
    sed '0,/^\.\.\.$/d' jiandao/xkjd6.${dict}.dict.yaml >> jiandao/xkjd6.dict.yaml && \
    rm jiandao/xkjd6.${dict}.dict.yaml
done && \
rm jiandao/xkjd6.yingwen.dict.yaml jiandao/xkjd6.extended.dict.yaml && \
cp jiandao/xkjd6.*.yaml ${SCHEMAS}/ && \
cp jiandao/lua/* ${SCHEMAS}/lua/ && \
cp jiandao/rime.lua ${SCHEMAS}/ && \
echo "fetch jiandao done."

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
sed -i -n '/import_tables/q;p' clover/clover.dict.yaml && \
cat '...' >> clover/clover.dict.yaml && \
for dict in clover.base clover.phrase THUOCL_animal THUOCL_caijing THUOCL_car THUOCL_chengyu THUOCL_diming THUOCL_food THUOCL_IT THUOCL_law THUOCL_lishimingren THUOCL_medical THUOCL_poem sogou_new_words
do
    sed '0,/^\.\.\.$/d' clover/${dict}.dict.yaml >> clover/clover.dict.yaml && \
    rm clover/${dict}.dict.yaml
done && \
cp clover/*.yaml ${SCHEMAS}/ && \
cp clover/opencc/symbol* ${SCHEMAS}/opencc/ && \
echo "fetch clover done."

# 🇯🇵日本語
# https://github.com/gkovacs/rime-japanese
rm -rf japanese && \
git clone --depth 1 https://github.com/gkovacs/rime-japanese japanese && \
cp japanese/*.yaml ${SCHEMAS}/ && \
echo "fetch japanese done."

# 🍲蜀拼-重庆
# https://github.com/Papnas/shupin
rm -rf shupin && \
git clone --depth 1 https://github.com/Papnas/shupin && \
cp shupin/*.dict.yaml ${SCHEMAS}/ && \
cp shupin/shupin_congqin.schema.yaml ${SCHEMAS}/ && \
echo "fetch shupin-congqin done."

# 😂绘文字
# https://github.com/rime/rime-emoji
if command -v opencc &> /dev/null
then
    rm -rf emoji
    git clone --depth 1 https://github.com/rime/rime-emoji emoji
    opencc -c t2s.json -i emoji/opencc/emoji_category.txt | awk '!seen[$1]++' > ${SCHEMAS}/opencc/emoji_category.txt
    opencc -c t2s.json -i emoji/opencc/emoji_word.txt | awk '!seen[$1]++' > ${SCHEMAS}/opencc/emoji_word.txt
    cp emoji/opencc/emoji.json ${SCHEMAS}/opencc/
    echo "fetch emoji done."
fi
