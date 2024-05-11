###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###############################
### Disk drives performance ###
###############################

number=11.1
en_name="Checking Disk drives performance"
ru_name="Определение производительности дисковой подсистемы"

pre()
{
	# Skipping this test when not requested or when no drives are found
	[ -n "$fio_test" ] && [ -n "$drives" ] ||
		return $TEST_SKIPPED
	return $TEST_ALLOWED
}

testcase()
{
	local devname filename cmd
	local i swap_uuid swap_label
	local tested=0 check_list=( )
	local rc swaps=( ) mounted=( )
	local pdev fs=8589934592 # 8 GiB

	# Using POSIX output in some cases
	if [ -n "$username" ] && [ "$langid" != en ]; then
		export LANG=C
	fi

	# Searching active SWAPs >= 8 GiB
	cmd="${L190-Searching active SWAP devices}"
	printf "$cmd...\n" |tee -a -- "$logfile"
	rc="$(grep -sE '^/dev/' /proc/swaps |cut -f1 -d' ')"
	#
	for devname in $rc _; do
		[ "$devname" != _ ] && [ -b "$devname" ] ||
			continue
		get_whole_disk pdev "$devname"
		in_array "${pdev##/dev/}" $drives ||
			continue
		! in_array "$pdev" "${check_list[@]}" ||
			continue
		cmd="$(blockdev --getsize64 "$devname" 2>/dev/null ||:)"
		[ -n "$cmd" ] && [ "$cmd" -ge "$fs" ] 2>/dev/null ||
			continue
		check_list+=( "$pdev" )
		swaps+=( "${devname##/dev/}" )
		( cmd="${L191-Suitable SWAP device found: @BOLD@}"
		  printf "  - $(bold "$cmd")" "$devname"
		  [ "$pdev" = "$devname" ] ||
			printf " (%s)" "$pdev"
		  printf "\n"
		) |tee -a -- "$logfile"
	done

	# Searching for other mounted devices
	cmd="${L192-Searching for other mounted devices}"
	printf "$cmd...\n" |tee -a -- "$logfile"
	rc="$(grep -sE '^/dev/' /proc/mounts |cut -f1 -d' ')"
	#
	for devname in $rc _; do
		[ "$devname" != _ ] && [ -b "$devname" ] ||
			continue
		get_whole_disk pdev "$devname"
		in_array "${pdev##/dev/}" $drives ||
			continue
		! in_array "$pdev" "${check_list[@]}" ||
			continue
		filename="$(grep -sE "^$devname " /proc/mounts |
					tail -n1 |cut -f2 -d' ')"
		[ -n "$filename" ] ||
			continue
		cmd="$(df -B1 -- "$filename" 2>/dev/null |
			grep -sE "^$devname " |
			awk '{print $4;}')"
		[ -n "$cmd" ] && [ "$cmd" -ge "$fs" ] 2>/dev/null ||
			continue
		check_list+=( "$pdev" )
		mounted+=( "${devname##/dev/}" )
		( cmd="${L193-Suitable mounted device found: @BOLD@}"
		  printf "  - $(bold "$cmd")" "$devname"
		  [ "$pdev" = "$devname" ] ||
			printf " (%s)" "$pdev"
		  printf " -> ${CLR_BOLD}%s${CLR_NORM}\n" "$filename"
		) |tee -a -- "$logfile"
	done

	rc=0

	# Testing SWAP devices
	for devname in "${swaps[@]}"
	do
		# Using a SWAP partition
		filename="/dev/$devname"
		spawn swapoff -v -- "$filename" ||
			continue
		cmd="blkid -c /dev/null -o value -s"
		swap_uuid="$(spawn $cmd UUID -- "$filename")"
		swap_label="$(spawn $cmd LABEL -- "$filename")"
		spawn wipefs -a -- "$filename"
		pdev="${check_list[$tested]}"
		device_test "$pdev" "$filename" ||
			rc="$?"
		spawn wipefs -a -- "$filename"
		spawn mkswap ${swap_label:+-L "$swap_label"} \
			-U "$swap_uuid" -- "$filename" |
				tee -a -- "$logfile"
		spawn swapon -v -- "$filename"
		tested=$((1 + $tested))
		printf "\n"
	done

	i="$tested"

	# Testing mounted devices
	for devname in "${mounted[@]}"
	do
		# Using a temporary file on a mounted file system
		filename="$(grep -sE "^/dev/$devname " /proc/mounts |
						tail -n1 |cut -f2 -d' ')"
		if [ -z "$filename" ]; then
			cmd="${L194-The device @BOLD@ will be skipped}"
			printf "$(bold "$cmd")...\n" "/dev/$devname" |
				tee -a -- "$logfile"
			i=$((1 + $i))
			continue
		elif [ "$filename" = / ]; then
			filename="/.TeSTfile-8G.fio"
		else
			filename="$filename/.TeSTfile-8G.fio"
		fi

		pdev="${check_list[$i]}"
		device_test "$pdev" "$filename" ||
			rc="$?"
		spawn rm -f -- "$filename"
		tested=$((1 + $tested))
		i=$((1 + $i))
		printf "\n"
	done

	# Checking for remaining disks
	for devname in $drives; do
		! in_array "/dev/$devname" "${check_list[@]}" ||
			continue
		cmd="${L194-The device @BOLD@ will be skipped}"
		printf "$(bold "$cmd")...\n" "/dev/$devname" |
			tee -a -- "$logfile"
		if [ -n "$unsafe_diskperf" ]; then
			cmd="${L195-Insecure testing will be implemented later!}"
			printf "${CLR_ERR}${cmd}${CLR_NORM}\n"
		fi
	done

	[ "$rc" = 0 ] ||
		return $TEST_FAILED
	[ "$tested" != 0 ] ||
		return $TEST_SKIPPED
	return $TEST_PASSED
}

# Checks one specified device
#
device_test()
{
	local msg dev="$1" filename="$2"
	local list testname direct=1 rc=0
	local datadir="/var/lib/$progname"

	msg="${L196-Testing the device @BOLD@...}"
	printf "$(bold "$msg")\n" "$dev" |
		tee -a -- "$logfile"
	# shellcheck disable=SC2207
	list=( $(find "$datadir" -type f -name '*.fio') )

	spawn mkdir -p -- "fio-${dev##/dev/}"
	spawn cd -- "fio-${dev##/dev/}"

	( printf "filename=%s\n" "$filename"
	  cat -- "$datadir"/fio.ini
	) >test.ini

	for testname in "${list[@]}"; do
		spawn cp -Lf -- "$testname" ./
		testname="${testname##*/}"
		testname="${testname%.fio}"

		( spawn fio -- "$testname.fio" ||
		  printf "\nFAILED: %s\n" "$?"
		) |tee -- "$testname.log"

		if [ "$direct" = 1 ] &&
		   tail -n1 -- "$testname.log" |grep -qsE '^FAILED: '
		then
			msg="${L197-Failure. Let\'s try again with direct=0}"
			printf "\n${CLR_WARN}${msg}${CLR_NORM}...\n"
			spawn sed -i -E 's/^direct=1$/direct=0/' test.ini
			( spawn fio -- "$testname.fio" ||
			  printf "\nFAILED: %s\n" "$?"
			) |tee -- "$testname.log"
			direct=0
		fi

		tail -n1 -- "$testname.log" |grep -qsE '^FAILED: ' && rc=1 ||:
		spawn rm -f -- "$testname.fio"
		printf "\n"
	done

	spawn cd ..

	return $rc
}

# Determines the entire disk device name for any
# specified device, such as a disk partition.
#
get_whole_disk()
{
	local varname="$1" partdev="$2"
	local number sysfs partn whole=

	number="$(mountpoint -x -- "$partdev")"
	sysfs="$(readlink -fv -- "/sys/dev/block/$number")"

	if [ -r "$sysfs/partition" ]; then
		read -r partn <"$sysfs/partition" ||
			partn=
		if [ -n "$partn" ]; then
			case "$partdev" in
			*[0-9]p$partn)
				whole="${partdev%%p"$partn"}"
				;;
			*$partn)
				whole="${partdev%%"$partn"}"
				;;
			esac
		fi
		[ -n "$whole" ] && [ -b "$whole" ] &&
		[ -r "/sys/block/${whole##/dev/}/${partdev##/dev/}/dev" ] ||
			whole=
	fi

	eval "$varname=\"${whole:-$partdev}\""
}

