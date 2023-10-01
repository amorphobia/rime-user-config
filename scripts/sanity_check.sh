#!/usr/bin/env bash

# Sanity Check
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

WORK=$(pwd)

sort -k2,2 -k4,4nr -k5,5nr -k3,3 dicts/cizu_append.txt | awk '!seen[$1,$2]++' > dicts/cizu_append_processed.txt
res=$(diff --strip-trailing-cr dicts/cizu_append.txt dicts/cizu_append_processed.txt)

if [[ $res ]]; then
    exit 1
fi

sort -k2,2 -s dicts/cizu_delete.txt | awk '!seen[$1,$2]++' > dicts/cizu_delete_processed.txt
res=$(diff --strip-trailing-cr dicts/cizu_delete.txt dicts/cizu_delete_processed.txt)

if [[ $res ]]; then
    exit 1
fi

sort -k2,2 -s dicts/cizu_modify.txt | awk '!seen[$1,$2]++' > dicts/cizu_modify_processed.txt
res=$(diff --strip-trailing-cr dicts/cizu_modify.txt dicts/cizu_modify_processed.txt)

if [[ $res ]]; then
    exit 1
fi

exit 0
