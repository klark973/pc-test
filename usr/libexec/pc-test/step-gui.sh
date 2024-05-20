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
	local tmpf text msg
	local fragment="${1-}"
	local rc="$TEST_PASSED"
	local url="file://${helpfile}#${fragment}"

	( printf "*** step-gui.sh::form_gui()\n"
	  printf "*** fragment=%s\n" "$fragment"
	  printf "*** number=%s\n" "${number-0}"
	) >>"$xorglog"

	L300="${L300-Passed}"
	L304="${L304-Skipped}"
	L306="${L306-Blocked}"
	L308="${L308-Failed}"

	text="Without closing windows of this program, perform testing"
	text="$text according to section %s of the methodology, and indicate"
	text="$text the result here. If the reason for skipping or failing"
	text="$text a test is not obvious, please leave your comments here."

	[ -z "$helpfile" ] || [ -z "$fragment" ] ||
		spawn xdg-open "$url" 2>>"$xorglog" ||:
	tmpf="$(spawn mktemp -qt -- "$progname-XXXXXXXX.tmp")"
	msg="$(printf "${L321-$text}" "${number-0}")"

	# The first method is only for yad v7.3 and higher
	if [ "$(spawn yad --version |cut -f1 -d.)" -ge 7 ] 2>/dev/null; then
		buttons_form || rc="$?"
	else
		# In p9 and p9_e2k we have broken yad v0.40.3
		select_form || rc="$?"
	fi

	printf "*** rc=%s\n" "$rc" >>"$xorglog"

	return $rc
}

buttons_form()
{
	local rc

	printf "*** buttons_form()\n" >>"$xorglog"

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

	while :; do
		rc=0
		yad	--on-top --enable-spell --mouse		\
			--always-print-result --width=620	\
			--window-icon=utilities-system-monitor	\
			--separator="" --item-separator=","	\
			--title="$(nls_title)" --text="$msg"	\
			--button="$L300,gtk-ok,$L301"		\
			--button="$L302,view-refresh,$L303"	\
			--button="$L304,system-run,$L305"	\
			--button="$L306,list-remove,$L307"	\
			--button="$L308,gtk-no,$L309" --form	\
			--field="${L320-Comments}:TXT" ""	\
			>"$tmpf" 2>>"$xorglog" || rc="$?"

		case "$rc" in
		0)  rc="$TEST_PASSED";;
		2)  rc="$TEST_SKIPPED";;
		3)  rc="$TEST_BLOCKED";;
		4)  rc="$TEST_FAILED";;
		*)  # 1 or 252
		    rm -f -- "$tmpf"
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

select_form()
{
	local rc

	printf "*** select_form()\n" >>"$xorglog"

	while :; do
		rc=0
		yad	--on-top --enable-spell --mouse		\
			--always-print-result --width=620	\
			--window-icon=utilities-system-monitor	\
			--separator="|" --item-separator=","	\
			--title="$(nls_title)" --text="$msg"	\
			--form --field="${L322-Result}:CB"	\
			--field="${L320-Comments}:TXT"		\
			"$L300,$L304,$L306,$L308" ""		\
			>"$tmpf" 2>>"$xorglog" || rc="$?"

		[ "$rc" != 0 ] ||
			break
		sleep .1
	done

	rc="$(head -n1 -- "$tmpf" |cut -f1 -d'|')"
	text="$(cat -- "$tmpf")"
	msg=$(( ${#rc} + 1 ))
	text="${text:$msg}"
	msg=$(( ${#text} - 1 ))
	text="${text:0:$msg}"

	case "$rc" in
	"$L300")   rc="$TEST_PASSED";;
	"$L304")   rc="$TEST_SKIPPED";;
	"$L306")   rc="$TEST_BLOCKED";;
	*)	   rc="$TEST_FAILED";;
	esac

	[ -z "$text" ] ||
		printf "%s\n" "$text" >"./comments-${number-0}.txt"
	spawn rm -f -- "$tmpf"

	return $rc
}

