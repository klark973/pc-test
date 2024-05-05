#!/bin/bash -efu

# Directories to check
bindirs="SCRIPTDIR:usr/bin:usr/libexec/pc-test"

# List of scripts to skip
skip_check=

# Not interested shellcheck codes that need to be excluded
sclist="
	SC1090
	SC1091
	SC2004
	SC2015
	SC2034
	SC2086
	SC2154
	SC2059
	SC1007
"

do_check()
{
	local fname nc

	find usr -type f -name '*.sh' -or -path usr/bin/pc-test |
	while read -r fname; do
		for nc in $skip_check _; do
			[ "$nc" != _ ] ||
				continue
			[ "$nc" != "$fname" ] ||
				continue 2
		done
		nc=( --norc -s bash "$@" -x "$fname" )
		shellcheck -P "$bindirs" "${nc[@]}" || :> ERROR
	done

	if [ -f ERROR ]; then
		rm -f ERROR
		return 1
	fi
}


excludes=
for e in $sclist; do
	excludes="${excludes:+$excludes,}$e"

	if [ "${1-}" = "-v" ] || [ "${1-}" = "--verbose" ]; then
		printf "*** Checking to %s...\n" "$e"
		do_check -i "$e" ||:
	fi
done

printf "*** Checking with all excludes...\n"
do_check -e "$excludes"

