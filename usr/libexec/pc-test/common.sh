###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

########################
### Common functions ###
########################

# Try to include NLS configuration
#
nls_config()
{
	[ ! -s "$libdir/l10n/$langid/$1.sh" ] ||
		. "$libdir/l10n/$langid/$1.sh"
}

# Enable native language support
#
nls_locale_setup()
{
	langid="${LC_ALL:-en_US.utf8}"
	langid="${LC_MESSAGES:-$langid}"
	langid="${LANG:-$langid}"
	langid="${langid%.*}"
	langid="${langid%_*}"

	[ -n "$langid" ] && [ -s "$libdir/l10n/$langid"/help.msg ] ||
		langid=en
	nls_config messages
}

# Returns the name of the test in the native language
#
nls_title()
{
	eval "printf '%s' \"\${${langid}_name-Untitled}\""
}

# Serach element "$1" in the array "$@" and return 0 if it found
#
in_array()
{
	local needle="$1"; shift

	while [ "$#" -gt 0 ]; do
		[ "$needle" != "$1" ] ||
			return 0
		shift
	done

	return 1
}

# Pause before automatically closing the terminal window
#
pause_before_exit()
{
	local msg

	[ -n "${desktop_icon_start-}" ] && [ -n "${DISPLAY-}" ] ||
		return 0

	if [ -n "$batchmode" ]; then
		sleep 5
	else
		msg="${L050-Press any key to close this window...}"
		printf "\n$msg\n"
		read -rs -n1 msg ||:
	fi
}

# Fatal situation handler
#
fatal()
{
	local msg fcode="${1:1}" fmt="$2"
	local E="${CLR_ERR-}" N="${CLR_NORM-}"

	shift 2
	[ -n "${F00-}" ] ||
		nls_config fatal
	msg="${F01-%s fatal[%s]}"
	eval "fmt=\"\${F$fcode-$fmt}\""

	if [ -z "${logfile-}" ] || [ ! -f "${logfile-}" ]; then
		printf "[${E}%s${N}] ${E}${msg}: ${fmt}${N}\n" \
			"$(date '+%T')" "$progname" "$fcode" "$@" >&2
	else
		printf "[${E}%s${N}] ${E}${msg}: ${fmt}${N}\n" \
			"$(date '+%T')" "$progname" "$fcode" "$@" |
		tee -a -- "$logfile" >&2
	fi

	remove_desktop_file
	pause_before_exit
	exit 1
}

# Unexpected error handler
#
unexpected_error()
{
	local rv="$?"

	trap - ERR
	fatal F02 "Unexpected error #%s catched in %s[#%s]!" "$rv" "$2" "$1"
}

# Returns 0, if specified package is installed
#
is_pkg_installed()
{
	rpm -q -- "$@" &>/dev/null
}

# Returns 0, if specified package is available to install
#
is_pkg_available()
{
	apt-cache show -- "$@" &>/dev/null
}

# Returns 0, if specified name is executable program
#
has_binary()
{
	type -p -- "$1" >/dev/null
}

# Customizes console colors
#
setup_console()
{
	# Console mode
	case "$colormode" in
	always)	colormode=1;;
	never)	colormode="";;
	*)	[ -t 1 ] && colormode=1 || colormode="";;
	esac

	# Resetting on dumb terminals
	if [ -z "$colormode" ]; then
		CLR_NORM=
		CLR_BOLD=
		CLR_LC1=
		CLR_LC2=
		CLR_OK=
		CLR_ERR=
		CLR_WARN=
	fi
}

# Paint single argument
#
bold()
{
	local b= n=

	if [ -n "$colormode" ]; then
		b="\\$CLR_BOLD"
		n="\\$CLR_NORM"
	fi

	printf "%s" "$1" |sed -e "s/@BOLD@/$b%s$n/"
}

# Shows the specified command
#
cmd_title()
{
	printf "[${CLR_BOLD}%s${CLR_NORM}] " "$(date '+%T')"
	[ "$EUID" = 0 ] && printf "${CLR_ERR}#" || printf "${CLR_OK}\$"
	printf " ${CLR_LC1}%s${CLR_NORM}\n" "$1"
}

# Runs a command with additional logging for debugging purposes
#
spawn()
{
	if [ -f "$logfile" ]; then
		cmd_title "$*" |tee -a -- "$logfile" >&2
	else
		cmd_title "$*" >&2
	fi

	"$@" || return $?
}

# This is the same as the previous one, but for cases without
# a log or for commands with output only to stderr
#
spawn2()
{
	cmd_title "$*" >&2
	"$@" || return $?
}

# Restarts this program with root privileges
#
restart_as_root()
{
	local msg add=

	if [ -n "$update_apt_lists" ] &&
	   [ -n "$dist_upgrade" ] && [ -n "$update_kernel" ]
	then
		add=" --update"
	elif [ -z "${update_apt_lists}${dist_upgrade}${update_kernel}" ]; then
		add=" --no-update"
	elif [ -z "$update_apt_lists" ]; then
		add=" --no-sources"
	fi

	if [ -s "$HOME/.local/share/$progname/sudo.UID" ]; then
		sudo $scriptname --uid="$EUID"${add}
	else
		msg="${L051-Root privileges required: sudo not yet configured for}"
		printf "${CLR_WARN}${msg} '%s'!${CLR_NORM}\n" "${USER-UID $EUID}"
		su - -c "$scriptname --uid=${EUID}${add}"
	fi
}

# Copies the desktop file to the user startup directory
#
copy_desktop_file()
{
	# Autorun doesn't work on p9, c9f1 and c9f2 because
	# /usr/bin/xdg-terminal is not packaged into the xdg-utils
	#
	if [ "$EUID" != 0 ] && [ -z "$disable_autorun" ] &&
	   [ -n "${DISPLAY-}" ] && [ -d "$HOME"/.config/autostart ]
	then
		sed 's,/launcher\.sh$,/resume.sh,' \
			"/usr/share/applications/$progname.desktop" \
			>"$HOME/.config/autostart/$progname.desktop"
		chmod 644 "$HOME/.config/autostart/$progname.desktop"
	fi
}

# Removes the desktop file
#
remove_desktop_file()
{
	rm -f -- "${homedir:-$HOME}/.config/autostart/$progname.desktop"
}

# Shows one header line
#
draw_title_line()
{
	local rc="$1" no="$2" text="$3"

	case "$rc" in
	"$TEST_RUNNING")
		printf "${CLR_WARN}Running${CLR_NORM}... "
		;;
	"$TEST_PASSED")
		printf "[${CLR_OK}PASSED${CLR_NORM}  ] "
		;;
	"$TEST_SKIPPED")
		printf "[${CLR_WARN}SKIPPED${CLR_NORM} ] "
		;;
	"$TEST_BLOCKED")
		printf "[${CLR_ERR}BLOCKED${CLR_NORM} ] "
		;;
	*)	# FAILED
		printf "[${CLR_ERR}FAILED${CLR_NORM}  ] "
		;;
	esac

	printf "${CLR_WARN}%s. " "$no"
	printf "${CLR_LC2}%s${CLR_NORM}\n" "$text"
}

# Shows results of passed steps
#
show_results()
{
	local rc step title

	[ -s "$workdir"/STATE/RESULTS ] ||
		return 0

	while read -r rc step; do
		. "$libdir/steps/$step.sh"

		title="$(nls_title)"
		draw_title_line "$rc" "${number-1}" "$title"
	done <"$workdir"/STATE/RESULTS
}

# Shows the title before each test
#
show_test_title()
{
	local title

	title="$(nls_title)"
	draw_title_line "$TEST_RUNNING" "${number-1}" "$title..."
}

# Checks for the next step in the test plan and moves on to it
#
have_next_step()
{
	local planfile="$workdir/STATE/$testplan"
	local statfile="$workdir/STATE/STATUS"
	local stepfile="$workdir/STATE/STEP"
	local title

	# Checking current step in the test plan, it can be called once
	[ -s "$planfile" ] && grep -qsE "\s${stepname}$" "$planfile" ||
		return 1
	rm -f -- "$stepfile"

	# Reading last result
	if [ -s "$statfile" ]; then
		status="$(head -n1 -- "$statfile")"
		rm -f -- "$statfile"
	fi

	# Showing last result
	title="$(nls_title)"
	draw_title_line "${status:-0}" "${number:-1}" "$title"

	# Saving last result
	if [ -f "$logfile" ]; then
		draw_title_line "${status:-0}" "${number:-1}" \
					"$title" >>"$logfile"
	fi
	if [ -d "$workdir"/STATE ]; then
		printf "%s\t%s\n" "$status" "$stepname" \
				>>"$workdir"/STATE/RESULTS
	fi

	# Removing the last passed step
	sed -i -E "/\s${stepname}$/d" "$planfile"
	stepname="$(head -n1 -- "$planfile" |cut -f2)"
	[ -n "$stepname" ] ||
		return 1
	printf "%s\n" "$stepname" >"$stepfile"
	[ "$EUID" != 0 ] || [ -z "$username" ] ||
		chown -- "$username":"$username" "$stepfile"
	return 0
}

# Allows to terminate the current test early
#
break_step()
{
	status="${1-$TEST_PASSED}"

	# shellcheck disable=SC2164
	cd -- "$workdir"/

	if [ "$EUID" = 0 ] && [ -n "$username" ] && [ -d ./TMP-ROOT ]; then
		chown -R -- "$username":"$username" ./TMP-ROOT
		(set +f; mv -f ./TMP-ROOT/* ./ ||:) 2>/dev/null
		rm -rf ./TMP-ROOT
	fi

	if [ -d ./STATE ]; then
		printf "%s\n" "$status" >./STATE/STATUS
		[ "$EUID" != 0 ] || [ -z "$username" ] ||
			chown -- "$username":"$username" ./STATE/STATUS
	fi

	have_next_step || remove_desktop_file
}

# Breaks the current test and restarts the system
#
system_restart()
{
	local msg t=5 rc="${1-$TEST_PASSED}"

	# Breaking the test
	break_step "$rc"

	# Showing last message
	if [ -z "$batchmode" ]; then
		msg="The update is complete. Press any key to reboot..."
		printf "\n${L052-$msg}\n"
		read -rs -n1 rc ||:
	else
		msg="The update is complete. After %s"
		msg="$msg seconds the system will reboot..."
		printf "\n${L053-$msg}\n" "$t"
		sleep "$t"
	fi

	reboot
}

# Writes configuration of the test
#
write_config()
{
	local key value list
	local sf="$workdir/STATE/settings.ini"

	list="$(grep -vsE '^(#|$)' "$libdir"/internal.sh |cut -f1 -d= |
			grep -vsE '^(launchmode|username|homedir)$')"

	for key in $list; do
		eval "value=\"\${$key-}\""
		printf "%s=%q\n" "$key" "$value"
	done >"$sf"

	[ "$EUID" != 0 ] || [ -z "$username" ] ||
		chown -- "$username":"$username" "$sf"
	return 0
}

