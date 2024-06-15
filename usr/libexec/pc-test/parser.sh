###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

#########################################
### The command-line arguments parser ###
#########################################

parse_cmdline()
{
	local l_opts="auto,continue,finish,start,batch,color:,date:,name:"
	      l_opts="$l_opts,no-autorun,no-sources,no-update,update,uid:"
	      l_opts="$l_opts,desktop-icon,version,help"
	local s_opts="+ACFSbc:d:n:vh"
	local msg

	l_opts=$(getopt -n "$progname" -o "$s_opts" -l "$l_opts" -- "$@") ||
		show_usage
	eval set -- "$l_opts"
	while [ "$#" != 0 ]; do
		case "$1" in
		-A|--auto)
			set_launch auto
			;;
		-C|--continue)
			set_launch continue
			;;
		-F|--finish)
			set_launch finish
			;;
		-S|--start)
			set_launch start
			;;
		-b|--batch)
			batchmode=1
			;;
		-c|--color)
			case "${2-}" in
			always|never|auto)
				colormode="$2"
				;;
			*)	msg="Invalid color mode: \'%s\'."
				show_usage F12 "$msg" "${2-}"
				;;
			esac
			shift
			;;
		-d|--date)
			[ -n "${2-}" ] && printf "%s\n" "${2-}" |
			grep -qsE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ||
				show_usage
			repodate="$2"
			shift
			;;
		-n|--name)
			compname="$(echo "${2-}" |tr -d ' ' |
					sed -e 's/[\(\),].*$//')"
			shift
			;;
		--update)
			update_apt_lists=1
			dist_upgrade=1
			update_kernel=1
			;;
		--no-sources)
			update_apt_lists=
			;;
		--no-update)
			update_apt_lists=
			dist_upgrade=
			update_kernel=
			;;
		--no-autorun)
			disable_autorun=1
			;;
		--uid)	check_uid "${2-}"
			set_launch continue
			shift
			;;
		--desktop-icon)
			desktop_icon_start=1
			;;
		-v|--version)
			show_version
			;;
		-h|--help)
			show_help
			;;
		--)	shift
			break
			;;
		-*)	msg="Unsupported option: \'%s\'."
			show_usage F13 "$msg" "$1"
			;;
		*)	break
			;;
		esac
		shift
	done

	# Checking for completeness and consistency
	[ -n "$launchmode" ] ||
		launchmode=auto
	[ -n "$colormode" ] ||
		colormode=auto
	if [ "$#" != 0 ]; then
		msg="To many argument(s): %s"
		show_usage F14 "$msg" "$*"
	fi
}

show_version()
{
	printf "%s %s %s\n" "$progname" "$PCTEST_VERSION" "$PCTEST_BUILD_DATE"
	exit 0
}

show_help()
{
	local helpfile="$libdir/l10n/$langid/help.msg"

	[ -s "$helpfile" ] ||
		help="$libdir/l10n/en/help.msg"
	sed "s/@PROG@/$progname/g" "$helpfile"
	exit 0
}

show_usage()
{
	local fcode msg

	if [ "$#" -ge 2 ]; then
		fcode="$1"
		msg="$2"
		shift 2
		[ -n "${F00-}" ] ||
			nls_config fatal
		eval "msg=\"\${${fcode}-$msg}\""
		printf "$msg\n" "$@" >&2
	fi

	msg="Invalid command-line usage. Try \'%s -h\' for more details."
	fatal F03 "$msg" "$progname"
}

set_launch()
{
	local msg="The program launch mode already specified: \'%s\'."

	[ -z "$launchmode" ] ||
		show_usage F15 "$msg" "$launchmode"
	launchmode="$1"
}

check_uid()
{
	local flag user_id="$1"

	[ -n "$user_id" ] ||
		show_usage
	[ "$EUID" = 0 ] ||
		fatal F16 "You must be root for using --uid=<UID>."
	[ "$user_id" != 0 ] && [ "$user_id" != root ] &&
	getent passwd "$user_id" &>/dev/null &&
	[ "$(getent passwd "$user_id" |cut -f3 -d:)" != 0 ] ||
		fatal F17 "Invalid user ID: \'%s\'." "$user_id"
	trap : INT TERM QUIT HUP USR1 USR2

	username="$(getent passwd "$user_id" |cut -f1 -d:)"
	homedir="$(getent passwd "$user_id" |cut -f6 -d:)"

	# One-time initialization: writing sudo settings only once
	if ! grep -qs -- "NOPASSWD: $scriptname" /etc/sudoers; then
		cat >>/etc/sudoers <<-EOF

		# Allow $username to execute $progname and dmesg
		$username ALL=(ALL:ALL) NOPASSWD: $scriptname,$(which dmesg)
		EOF

		flag="$homedir/.local/share/$progname/sudo.UID"
		printf "[%s] Sudo has been configured for %s: %s\n" \
			"$(date '+%F %T')" "$username" "$flag" \
			>>"/var/log/$progname.log"
		date >"$flag" && chown -- "$username:$username" "$flag"
	fi
}

