###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

#######################################
### Express test of main components ###
#######################################

number=9
en_name="Express test of main components"
ru_name="Экспресс-тест основных компонентов"

vsamples=(
	DcvvWjExea4
	k7dy1B6bOeM
	Rwe5Aw3KPHY
	IVAWBpeNAmE
	UV0mhY2Dxr0
)

pre()
{
	local iface cnt=0

	[ -n "$sound_test" ] && [ -n "$xprss_test" ] && [ -n "$have_xorg" ] ||
		return $TEST_SKIPPED
	[ -n "$have_mate" ] || [ -n "$have_kde5" ] || [ -n "$have_xfce" ] ||
		return $TEST_SKIPPED

	for iface in $(ls /sys/class/net/) _; do
		case "$iface" in
		lo|_)	continue;;
		*)	cnt=$((1 + $cnt));;
		esac
	done

	[ "$cnt" -gt 0 ] ||
		return $TEST_SKIPPED
	spawn grep -qs ' Device-1: ' inxi-G.txt ||
		return $TEST_SKIPPED
	spawn ip route |grep -qsE '^default via ' ||
		return $TEST_BLOCKED
	[ -n "${DISPLAY-}" ] && has_binary xdg-open && has_binary yad ||
		return $TEST_BLOCKED
	return $TEST_ALLOWED
}

testcase()
{
	local rc="$TEST_PASSED"
	local idx=$(( $RANDOM % ${#vsamples[@]} ))
	local random_video="https://youtu.be/${vsamples[$idx]}"
	local url="file://$helpfile#_экспресс_тест_основных_компонентов"

	. "$libdir"/step-gui.sh

	[ -z "$helpfile" ] ||
		spawn xdg-open "$url" ||:
	spawn xdg-open "${local_video_sample:-$random_video}" ||:
	form_gui || rc="$?"
	unset vsamples

	return $rc
}
