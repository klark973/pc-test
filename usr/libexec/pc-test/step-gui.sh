###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

################################
### Graphical user interface ###
################################

form_gui()
{
	local rc tmpf text

	L300="${L300-Passed}"
	L304="${L304-Skipped}"
	L306="${L306-Blocked}"
	L308="${L308-Failed}"
	L302="${L302-Clear}"
	L303="${L303-Clear this form}"
	L309="${L309-The test was passed with errors or incompletely}"

	text="The test was successfully passed and the expected result"
	text="$text was obtained at all stages without using workarounds"
	L301="${L301-$text}"

	text="The test was not performed, for example, due to lack of hardware"
	text="$text, the ability to organize a stand, or for some other reason"
	L305="${L305-$text}"

	text="It is not possible to perform this test, for example"
	text="$text, due to previously discovered problems"
	L307="${L307-$text}"

	text="Without closing windows of this program, perform testing"
	text="$text according to section %s of the methodology, and indicate"
	text="$text the result here. If the reason for skipping or failing"
	text="$text a test is not obvious, please leave your comments here."
	text="$(printf "${L321-$text}" "${number-0}")"

	tmpf="$(spawn mktemp -qt -- "$progname-XXXXXXXX.tmp")"

	while :; do
		rc=0
		yad	--on-top --enable-spell --mouse		\
			--always-print-result --width=620	\
			--separator="" --item-separator=","	\
			--title="$(nls_title)" --text="$text"	\
			--button="$L300,gtk-ok,$L301"		\
			--button="$L302,view-refresh,$L303"	\
			--button="$L304,system-run,$L305"	\
			--button="$L306,list-remove,$L307"	\
			--button="$L308,gtk-no,$L309" --form	\
			--field="${L320-Comments}:TXT" ""	\
		>"$tmpf" 2>>yad.log || rc="$?"

		case "$rc" in
		0)  rc="$TEST_PASSED";;
		2)  rc="$TEST_SKIPPED";;
		3)  rc="$TEST_BLOCKED";;
		4)  rc="$TEST_FAILED";;
		*)  # 1 or 252
		    spawn rm -f -- "$tmpf"
		    sleep .1
		    continue
		    ;;
		esac

		break
	done

	text="$(cat -- "$tmpf")"

	if [ -n "$text" ]; then
		spawn mv -f -- "$tmpf" "./comments-${number-0}.txt"
	else
		spawn rm -f -- "$tmpf"
	fi

	return $rc
}

