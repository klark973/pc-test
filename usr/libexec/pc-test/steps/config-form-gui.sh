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
	local tag args i=1
	local val h n title

	title="$(nls_title)"
	n=${#tests_list[@]}
	h="$(( $n / 2 ))"
	args=(
		yad --borders=15 --form
		"--separator=\" \""
		"--title=\"$title\""
	)

	#yad --borders=15 --form --separator=" " \
	#	--title="<TITLE>" <ITEMS>... <VALUES>...

	while [ "$i" -lt "$n" ]; do
		val="${tests_list[$i]}"
		args+=( "--field=\"$val:CHK\"" )
		i=$((2 + $i))
	done
	i=0
	while [ "$i" -lt "$n" ]; do
		val="${tests_list[$i]}"
		eval "tag=\"\${${val}_test-}\""
		i=$((2 + $i))
		if [ -n "$tag" ]; then
			args+=( TRUE )
		else
			args+=( FALSE )
		fi
	done

	#r=$(yad \
	#	--borders=15 --form --separator=" "			\
	#	--title="Defining a Test Plan"				\
	#	--field="Hardware components firmware update:CHK"	\
	#	--field="Additional diagnostics for developers:CHK"	\
	#	--field="Testing Infiniband/RDMA:CHK"			\
	#	--field="Testing Sound Card:CHK"			\
	#	--field="Testing NUMA Technology:CHK"			\
	#	--field="Testing IMPI Management:CHK"			\
	#	--field="Testing internal Web-camera:CHK"		\
	#	--field="Testing Console Power Management:CHK"		\
	#	--field="Testing Fingerprint Scanner:CHK"		\
	#	--field="Testing Bluetooth interface:CHK"		\
	#	--field="Testing Smart-cards interface:CHK"		\
	#	--field="Checking Disk drives performance:CHK"		\
	#	--field="Checking 2D/3D-Video performance:CHK"		\
	#	FALSE TRUE TRUE FALSE TRUE TRUE FALSE			\
	#	FALSE FALSE FALSE FALSE FALSE FALSE 2>yad.log)"

	while :; do
		i=0
		# shellcheck disable=SC2207,SC2294
		val=( $(eval "${args[@]}" 2>yad.log) ) ||
			i="$?"
		[ "$i" != 0 ] || [ "${#val[@]}" = 0 ] ||
			break
		sleep .1
	done

	i=0
	h=0
	while [ "$i" -lt "$n" ]; do
		tag="${tests_list[$i]}_test"
		i=$((2 + $i))
		eval "args=\"\${val[$h]}\""
		# shellcheck disable=SC2128,SC2178,SC2178
		[ "$args" = TRUE ] && args=1 ||
			args=
		h=$((1 + $h))
		# shellcheck disable=SC2128
		eval "$tag=$args"
	done
}

form_gui

