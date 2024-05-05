###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###########################################
### Hardware components firmware update ###
###########################################

number=6
en_name="Checking the ability to hardware components firmware updating"
ru_name="Проверка возможности обновления прошивки компонентов оборудования"

pre()
{
	# Skipping this test when not requested or if fwupd is not available
	[ -n "$fwupd_test" ] ||
		return $TEST_SKIPPED
	has_binary fwupdmgr ||
		return $TEST_BLOCKED
	return $TEST_ALLOWED
}

testcase()
{
	local rc="$TEST_ALLOWED"

	# 6.1. List devices
	printf "===[ Devices list:\n"
	spawn fwupdmgr get-devices ||
		rc="$TEST_BLOCKED"
	printf "===]\n\n"

	# 6.2. List updates
	printf "===[ Updates list:\n"
	spawn fwupdmgr get-updates -y ||
		rc="$TEST_BLOCKED"
	printf "===]\n\n"

	# 6.3. Doing update
	if [ "$rc" = "$TEST_ALLOWED" ]; then
		printf "===[ Update process:\n"
		spawn fwupdmgr update ||
			rc="$TEST_FAILED"
		printf "===]\n\n"

		# Resetting systemd journal
		if [ -n "$have_systemd" ]; then
			spawn systemctl stop systemd-journald
			(set +f; rm -rf /var/log/journal/* ||:) 2>/dev/null
		fi

		system_restart "$rc"
	fi

	return "$rc"
}

