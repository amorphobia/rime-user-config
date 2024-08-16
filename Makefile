SHELL=/usr/bin/bash
# https://stackoverflow.com/a/12838683/6676742
export LC_ALL := C

sort: opencc/tofu.txt
	sort -o opencc/tofu.txt{,}

check: sort
	bash scripts/sanity_check.sh

.PHONY: sort check
