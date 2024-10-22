###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

##############################
### Collecting system logs ###
##############################

number=7
en_name="Checking and saving logs"
ru_name="Проверка и сохранение журналов"

testcase()
{
	local filter="(panic|fatal|fail|error|warning)"

	# Using POSIX output in some cases
	if [ -n "$username" ] && [ "$langid" != en ]; then
		export LANG=C
	fi

	# 7.2. dmesg and errors
	dmesg | grep -isE -- "$filter" |
		grep -vs ' Command line: ' |
		grep -vs ' Kernel command line: ' |
		gzip -9qnc >dmesg_err.gz
	spawn dmesg -H -P --color=always |gzip -9qnc >dmesg.gz

	# All other for systemd only
	if [ -z "$have_systemd" ]; then
		return $TEST_PASSED
	fi

	# 7.3. failed services only
	spawn systemctl --failed |gzip -9qnc >systemctl_err.gz

	# 7.4. systemd journal and errors
	spawn journalctl -b |gzip -9qnc >journal.gz
	spawn journalctl -p err -b |gzip -9qnc >journal_err.gz

	# Additional systemd information
	if [ -n "$devel_test" ] && has_binary systemd-analyze; then
		spawn systemd-analyze --no-pager critical-chain >critical-chain.txt ||:
		spawn systemd-analyze --no-pager blame >systemd-blame.txt ||:
	fi
}

