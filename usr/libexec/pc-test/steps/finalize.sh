###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024-2025, ALT Linux Team

#############################
### Finalizing of testing ###
#############################

number=10.11
en_name="Final check of kernel messages"
ru_name="Контрольная проверка сообщений ядра"

testcase()
{
	local n

	# Using POSIX output in some cases
	if [ -n "$username" ] && [ "$langid" != en ]; then
		export LANG=C
	fi

	# 10.11. Final check of kernel messages
	spawn dmesg -H -P -T --color=always |gzip -9qnc >dmesg_final.gz

	# Removing an empty log
	[ -s "$xorglog" ] || spawn rm -f -- "$xorglog"

	# 7.1. Non-informative kernel messages (again)
	n="AER: (Corrected error message|Multiple Corrected error) received"
	[ "$(spawn dmesg |grep -scE -- "$n")" -le 9 ] || return $TEST_FAILED
}

