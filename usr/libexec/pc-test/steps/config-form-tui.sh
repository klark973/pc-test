###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###########################
### Text user interface ###
###########################

form_tui()
{
	local tag val title
	local v h n args i=0

	v="v$PCTEST_VERSION/$PCTEST_BUILD_DATE"
	title="$(nls_title)"
	n=${#tests_list[@]}
	h="$(( $n / 2 ))"
	[ -z "$can_install_mate" ] ||
		h=$((1 + $h))
	args=(
		dialog
		"--no-tags" "--shadow"
		"--backtitle" "\"PC-Test $v\""
		"--title" "\"[ $title ]\""
		"--checklist" "\"\"" $((6 + $h)) "$tui_form_width" "$h"
	)

	#dialog --no-tags --shadow --backtitle "PC-Test <version>"	\
	#	--title "[ <Title text> ]"				\
	#	--checklist <text> <height> <width> <list-height>	\
	#	[ <tag> <item> <on|off> ]...

	if [ -n "$can_install_mate" ]; then
		args+=( mate )
		args+=( "\"$mate_item\"" )
		args+=( off )
	fi

	while [ "$i" -lt "$n" ]; do
		tag="${tests_list[$i]}"
		args+=( "$tag" )
		i=$((1 + $i))

		val="${tests_list[$i]}"
		args+=( "\"$val\"" )
		i=$((1 + $i))

		eval "tag=\"\${${tag}_test-}\""

		if [ -n "$tag" ]; then
			args+=( on )
		else
			args+=( off )
		fi
	done

	#dialog --no-tags --shadow --backtitle "PC-Test vX.Y.Z/D"	\
	#	--title "[ Defining test parameters ]"			\
	#	--checklist "" 20 51 14					\
	#	mate "Installing MATE in ALT SP Server 10" off		\
	#	fwupd "Hardware components firmware update" off		\
	#	devel "Additional diagnostics for developers" on	\
	#	infb "Testing Infiniband/RDMA" on			\
	#	sound "Testing Sound Card" off				\
	#	numa "Testing NUMA Technology" on			\
	#	ipmi "Testing IMPI Management" on			\
	#	webcam "Testing internal Web-camera" off		\
	#	power "Testing Console Power Management" off		\
	#	fprnt "Testing Fingerprint Scanner" off			\
	#	bluez "Testing Bluetooth interface" off			\
	#	scard "Testing Smart-cards interface" off		\
	#	fio "Checking Disk drives performance" off		\
	#	v3d "Checking 2D/3D-Video performance" off		\
	#	2>RESULTS; clear; cat RESULTS; echo; rm -f RESULTS

	while :; do
		i=0
		exec 3>&1
		# shellcheck disable=SC2207,SC2294
		val=( $(eval "${args[@]}" 2>&1 1>&3) ) ||
			i="$?"
		exec 3>&-
		[ "$i" != 0 ] ||
			break
		sleep .1
	done

	clear

	install_mate=
	while [ "$i" -lt "$n" ]; do
		tag="${tests_list[$i]}"
		eval "${tag}_test="
		i=$((2 + $i))
	done

	for tag in "${val[@]}"; do
		if [ "$tag" = mate ]; then
			tag=install_mate
		else
			tag="${tag}_test"
		fi
		eval "$tag=1"
	done
}

form_tui

