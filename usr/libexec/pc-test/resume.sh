#!/bin/bash
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

################################################
### pc-test autorun script to resume testing ###
################################################

# Safety first
set -o errexit
set -o noglob
set -o nounset

# Executable file name
readonly progname="pc-test"

# Last working directory
readonly lastdir="$HOME/PC-TEST"

# The desktop file for pc-test autorun
readonly desktopfile="$HOME/.config/autostart/$progname.desktop"

# The command to be executed
readonly cmd="$progname --desktop-icon --continue"

# Checking files of the last testing
if [ ! -L "$lastdir" ] || [ -z "${DISPLAY-}" ] ||
   [ ! -s "$lastdir/$progname.log" ] || [ ! -s "$lastdir"/STATE/STEP ] ||
   [ ! -f "$lastdir"/STATE/start.txt ] || [ ! -s "$lastdir"/STATE/settings.ini ]
then
	exec rm -f -- "$desktopfile"
	exit 1
fi

# Reading system settings
. "$lastdir"/STATE/settings.ini

# Let the window manager finish loading the desktop first
if [ -n "${have_kde5-}" ] && type -p konsole >/dev/null; then
	sleep 5 && exec konsole -T "PC Test" -e $cmd
elif [ -n "${have_mate-}" ] && type -p mate-terminal >/dev/null; then
	sleep 5 && exec mate-terminal --window -t "PC Test" -e "$cmd"
elif [ -n "${have_xfce-}" ] && type -p xfce4-terminal >/dev/null; then
	sleep 5 && exec xfce4-terminal -T "PC Test" -e "$cmd"
else
	exec rm -f -- "$desktopfile"
fi

exit 1

