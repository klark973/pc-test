###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

############################
### Graphics performance ###
############################

number=11.2
en_name="Checking 2D/3D-Video performance"
ru_name="Определение производительности видеоподсистемы"

pre()
{
	# Skipping this test when not requested or if there is no X11 session
	[ -n "$v3d_test" ] && [ -n "${DISPLAY-}" ] ||
		return $TEST_SKIPPED
	return $TEST_ALLOWED
}

testcase()
{
	spawn glmark2 |tee glmark2.log
}

