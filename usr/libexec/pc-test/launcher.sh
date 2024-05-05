#!/bin/bash
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###############################
### DE-independent launcher ###
###############################

# Safety first
set -o errexit
set -o noglob
set -o nounset

have_kde5=
have_xfce=
have_mate=

is_pkg_installed()
{
	rpm -q -- "$1" &>/dev/null
}

has_binary()
{
	type -p -- "$1" &>/dev/null
}

if is_pkg_installed kde5; then
	have_kde5=1
fi

if is_pkg_installed xfce4-minimal ||
	is_pkg_installed xfce4-default
then
	have_xfce=1
fi

if is_pkg_installed mate-minimal ||
	is_pkg_installed mate-default ||
	is_pkg_installed mate-window-manager
then
	have_mate=1
fi

if [ -n "$have_kde5" ] && has_binary konsole; then
	exec konsole -T "PC Test" -e pc-test --desktop-icon
elif [ -n "$have_mate" ] && has_binary mate-terminal; then
	exec mate-terminal --window -t "PC Test" -e "pc-test --desktop-icon"
elif [ -n "$have_xfce" ] && has_binary xfce4-terminal; then
	exec xfce4-terminal -T "PC Test" -e "pc-test --desktop-icon"
fi

exit 1

