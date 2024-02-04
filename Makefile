export LC_ALL := C

sort: opencc/tofu.txt
	sort -o opencc/tofu.txt{,}

check: sort
	bash scripts/sanity_check.sh

.PHONY: sort check
