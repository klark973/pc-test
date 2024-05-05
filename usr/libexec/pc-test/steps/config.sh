###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###############################
### Test plan configuration ###
###############################

number=5.4
en_name="Defining a Test Plan"
ru_name="Определение плана тестирования"

pre()
{
	# Making changes in batch mode is not possible
	[ -z "$batchmode" ] ||
		return $TEST_SKIPPED
	[ -n "${DISPLAY-}" ] && has_binary yad || has_binary dialog ||
		return $TEST_BLOCKED
	return $TEST_ALLOWED
}

testcase()
{
	local wconf=

	nls_config config

	if [ -n "${DISPLAY-}" ] && has_binary yad; then
		. "$libdir"/steps/config-form-gui.sh

		wconf=1
	elif has_binary dialog; then
		# This global name is used only in form_tui()
		can_install_mate=

		# ALT SP Server 10 can have MATE (optional)
		if [ -n "$have_altsp" ] && [ -z "$have_xorg" ] &&
			[ "$distro" = SRV ] && [ "$repo" = c10f1 ]
		then
			can_install_mate=1
		fi

		. "$libdir"/steps/config-form-tui.sh

		unset can_install_mate
		wconf=1
	fi

	unset mate_item
	unset tests_list
	unset tui_form_width

	# Settings
	if [ -n "$wconf" ]; then
		write_config
		cat -- "$workdir"/STATE/settings.ini >config.ini
		wconf="\"${CLR_LC1}\" \$1 \"${CLR_BOLD}=${CLR_LC2}\" \$2 \"${CLR_NORM}\""
		cat -- "$workdir"/STATE/settings.ini |awk -F = "{print $wconf;}"
	fi
}

