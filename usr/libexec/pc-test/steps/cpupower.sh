###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

####################################
### Checking CPU frequency modes ###
####################################

number=10.1
en_name="Checking modes for changing processor frequency and power"
ru_name="Проверка режимов изменения частоты и мощности процессора"

testcase()
{
	local left=/sys/devices/system/cpu
	local o v i=0 n="$left/cpu0/cpufreq"
	local n_cores minf="" maxf="" scaling=1
	local noturbo="" governors="" saved_speed=( )
	local saved_governors=( ) saved_bias=( )
	local rc="" saved_min=( ) saved_max=( )
	local have_pwsv="" have_uspc=""
	local have_cons="" have_ondm=""

	# Using POSIX output in some cases
	if [ -n "$username" ] && [ "$langid" != en ]; then
		export LANG=C
	fi

	# Obtaining the supported minimum
	if [ -r "$n"/cpuinfo_min_freq ]; then
		minf="$(head -n1 -- "$n"/cpuinfo_min_freq)"
	elif [ -r "$n"/scaling_min_freq ]; then
		minf="$(head -n1 -- "$n"/scaling_min_freq)"
	fi

	# Obtaining the supported maximum
	if [ -r "$n"/cpuinfo_max_freq ]; then
		maxf="$(head -n1 -- "$n"/cpuinfo_max_freq)"
	elif [ -r "$n"/scaling_max_freq ]; then
		maxf="$(head -n1 -- "$n"/scaling_max_freq)"
	fi

	# Using hardware restrictions from the BIOS
	if [ -n "$maxf" ] && [ -r "$n"/bios_limit ]; then
		v="$(head -n1 -- "$n"/bios_limit)"
		[ -z "$v" ] || [ "$maxf" -le "$v" ] ||
			maxf="$v"
	fi

	# Determining the number of logical CPU cores
	n_cores="$(spawn grep -scE '^processor\s' /proc/cpuinfo)"

	# Checking the possibility of CPU Performance Scaling
	[ "$n_cores" != 0 ] && [ -n "$minf" ] && [ -n "$maxf" ] &&
	[ -n "$n_cores" ] && [ "$minf" -lt "$maxf" ] 2>/dev/null &&
	[ -r "$n"/scaling_available_governors ] &&
	[ -r "$n"/scaling_governor ] ||
		scaling=
	[ -r "$n"/cpuinfo_cur_freq ] || [ -r "$n"/scaling_cur_freq ] ||
		scaling=
	o=power/energy_perf_bias

	# Saving available PSP
	if [ -n "$scaling" ]; then
		governors="$(head -n1 -- "$n"/scaling_available_governors)"
		in_array powersave $governors    && have_pwsv=1 ||:
		in_array userspace $governors    && have_uspc=1 ||:
		in_array conservative $governors && have_cons=1 ||:
		in_array ondemand $governors     && have_ondm=1 ||:
	fi

	# Saving the current state of the CPU and cores
	spawn cpupower frequency-info |tee -a -- "$logfile"
	[ ! -r "$left"/intel_pstate/no_turbo ] ||
		noturbo="$(head -n1 -- "$left"/intel_pstate/no_turbo)"
	spawn : n_cores="$n_cores" scaling="$scaling" noturbo="$noturbo"
	spawn : minf="$minf" maxf="$maxf"

	# Intel Performance and EBH
	if have_cpu_var 0 "$o"; then
		spawn : Intel Performance and Energy Bias Hint

		# Saving current EBH values
		while [ "$i" -lt "$n_cores" ]; do
			save_cpu_array saved_bias "$i" "$o" ||
				break
			i=$((1 + $i))
		done

		# Do all CPU cores support EBH feature?
		spawn : n_cores="$n_cores" n_bias="${#saved_bias[@]}"
		spawn : "${saved_bias[@]}"
		i=0
	fi

	# CPU Performance Scaling
	if [ -n "$scaling" ]; then
		spawn : CPU Performance Scaling Policies

		# Saving current PSP values
		while [ "$i" -lt "$n_cores" ]; do
			o=cpufreq/scaling_governor
			save_cpu_array saved_governors "$i" "$o" ||
				break
			o=cpufreq/scaling_min_freq
			save_cpu_array saved_min "$i" "$o" ||
				break
			o=cpufreq/scaling_max_freq
			save_cpu_array saved_max "$i" "$o" ||
				break
			o=cpufreq/scaling_setspeed
			v="$(read_cpu_var "$i" "$o" 2>/dev/null ||
				echo "<unsupported>")"
			saved_speed[$i]="$v"
			i=$((1 + $i))
		done

		# Do all CPU cores support PSP feature?
		spawn : n_cores="$n_cores" n_gov="${#saved_governors[@]}" \
			n_min="${#saved_min[@]}" n_max="${#saved_max[@]}"
		i=0
	fi

	#
	# Reducing power and frequency to a minimum
	#

	# Turning off Turbo Mode
	if [ -n "$noturbo" ]; then
		echo 1 >"$left"/intel_pstate/no_turbo &&
		spawn : Intel SpeedStep Turbo Mode has been switched off ||:
	fi

	# Intel Performance and EBH again
	if [ "${#saved_bias[@]}" != 0 ]; then
		o=power/energy_perf_bias

		# Reducing power to a minimum
		while [ "$i" -lt "${#saved_bias[@]}" ]; do
			write_cpu 15 "$i" "$o"
			i=$((1 + $i))
		done

		i=0
	fi

	# CPU Performance Scaling again
	if [ "${#saved_max[@]}" != 0 ]; then
		while [ "$i" -lt "${#saved_max[@]}" ]; do
			o=cpufreq/scaling_governor
			v="${saved_governors[$i]}"

			# Setting a preferred policy
			if [ -n "$have_pwsv" ]; then
				[ "$v" = powersave ] ||
					write_cpu powersave "$i" "$o"
			elif [ -n "$have_uspc" ]; then
				[ "$v" = userspace ] ||
					write_cpu userspace "$i" "$o"
				v=SET-SPEED
			elif [ -n "$have_cons" ]; then
				[ "$v" = conservative ] ||
					write_cpu conservative "$i" "$o"
			elif [ -n "$have_ondm" ]; then
				[ "$v" = ondemand ] ||
					write_cpu ondemand "$i" "$o"
			fi

			# Setting the upper frequency limit
			if [ "${saved_max[$i]}" != "$maxf" ]; then
				o=cpufreq/scaling_max_freq
				write_cpu "$maxf" "$i" "$o"
			fi

			# Setting the lower frequency limit
			if [ "${saved_min[$i]}" != "$minf" ]; then
				o=cpufreq/scaling_min_freq
				write_cpu "$minf" "$i" "$o"
			fi

			# Setting a specific speed
			if [ "$v" = SET-SPEED ]; then
				o=cpufreq/scaling_setspeed
				! have_cpu_var "$i" "$o" ||
					write_cpu "$minf" "$i" "$o"
			fi

			i=$((1 + $i))
		done

		i=0
	fi

	# Cooling
	if [ -z "$scaling" ]; then
		spawn : Scaling control unavailable on this hardware
		rc="$TEST_BLOCKED"

	# With CONFIG_CPU_FREQ_STAT we can use this sysfs interface,
	# see: https://docs.kernel.org/cpu-freq/cpufreq-stats.html
	#
	elif have_cpu_var 0 cpufreq/stats/time_in_state; then
		if [ -n "$have_pwsv" ] || [ -n "$have_uspc" ]; then
			v=20
		else
			v=5
		fi

		o=cpufreq/stats/reset
		scaling="$(( ($maxf - $minf) / $v + $minf ))"
		spawn : Using cpufreq-stats with low boundary="$scaling"

		while [ "$i" -lt "$n_cores" ]; do
			write_cpu 1 "$i" "$o"
			i=$((1 + $i))
		done

		i=0; n=0
		spawn sleep 15
		o=cpufreq/stats/time_in_state

		while [ "$i" -lt "$n_cores" ]; do
			have_cpu_var "$i" "$o" ||
				break
			v="$(cat -- "$left/cpu$i/$o" |
				sort -nr -k2 |
				head -n1 |
				cut -f1 -d' ')"
			[ "$v" -gt "$scaling" ] ||
				n=$((1 + $n))
			i=$((1 + $i))
		done

		# Checking the counter
		spawn : n_cores="$n_cores" n="$n" i="$i"
		[ "$n" != 0 ] && [ "$n" = "$i" ] ||
			rc="$TEST_FAILED"
		i=0; scaling=1

	# When using "powersave" or "userspace" policies, we make sure
	# that all CPU cores have been switched to the minimal frequency
	#
	elif [ -n "$have_pwsv" ] || [ -n "$have_uspc" ]; then
		scaling="$(( ($maxf - $minf) / 20 + $minf ))"
		spawn : Using minimal frequency with low boundary="$scaling"
		spawn sleep 15
		v="$(read_freq)"
		spawn : $v
		n=0

		for i in $v; do
			[ "$i" -gt "$scaling" ] ||
				n=$((1 + $n))
		done

		# Checking the counter
		spawn : n_cores="$n_cores" n_pos="$n"
		[ "$n" = "$n_cores" ] ||
			rc="$TEST_FAILED"
		i=0; scaling=1

	# When using an unstable scaling policy such as "ondemand"
	# or "conservative", and without kernel-level statistics, we
	# make sure that the average frequency is close to the minimum
	#
	else
		scaling="$(( ($maxf - $minf) / 4 + $minf ))"
		spawn : Using dynamic policy with low boundary="$scaling"
		spawn sleep 15
		v="$(read_freq)"
		spawn : $v

		i="$(freq_min $v)"
		o="$(freq_avg $v)"
		n="$(freq_max $v)"
		spawn : N="$i" minf="$minf"
		spawn : A="$o" avgf=
		spawn : X="$n" maxf="$maxf"

		# Comparing the average frequency with the lower limit
		[ "$o" -le "$scaling" ] ||
			rc="$TEST_FAILED"
		i=0; scaling=1
	fi

	# Showing and saving results
	spawn cpupower monitor |tee -a -- "$logfile"
	spawn cpupower frequency-info -p |tee -a -- "$logfile"
	spawn cpupower frequency-info -m -f |tee -a -- "$logfile"

	#
	# Increasing power and frequency to a maximum
	#

	# CPU Performance Scaling again
	if [ "${#saved_max[@]}" != 0 ]; then
		o=cpufreq/scaling_governor
		n=cpufreq/scaling_setspeed

		if in_array performance $governors; then
			while [ "$i" -lt "${#saved_max[@]}" ]; do
				write_cpu performance "$i" "$o"
				i=$((1 + $i))
			done
		elif [ -n "$have_uspc" ]; then
			while [ "$i" -lt "${#saved_max[@]}" ]; do
				write_cpu userspace "$i" "$o"
				! have_cpu_var "$i" "$n" ||
					write_cpu "$maxf" "$i" "$n"
				i=$((1 + $i))
			done
		fi

		i=0
	fi

	# Intel Performance and EBH again
	if [ "${#saved_bias[@]}" != 0 ]; then
		o=power/energy_perf_bias

		# Increasing power to a maximum
		while [ "$i" -lt "${#saved_bias[@]}" ]; do
			write_cpu 0 "$i" "$o"
			i=$((1 + $i))
		done

		i=0
	fi

	# Turning on Turbo Mode
	if [ -n "$noturbo" ]; then
		echo 0 >"$left"/intel_pstate/no_turbo &&
		spawn : Intel SpeedStep Turbo Mode has been switched on ||:
	fi

	# Warming up and main testing
	spawn2 stress-ng --cpu 0 --numa 0 --cpu-method matrixprod \
		--tz --metrics --timeout 30 2>&1 |tee -a -- "$logfile"
	spawn2 stress-ng --cpu 0 --cpu-method matrixprod --tz \
		--metrics --timeout 20 2>&1 |tee -a -- "$logfile"
	stress-ng --cpu 0 --cpu-method matrixprod --metrics \
		--timeout 10 &>/dev/null & v="$!"
	spawn sleep 5
	spawn cpupower monitor |tee -a -- "$logfile"
	spawn cpupower frequency-info -p |tee -a -- "$logfile"
	spawn cpupower frequency-info -m -f |tee -a -- "$logfile"

	# Comparing the average frequency with the upper limit
	if [ -n "$scaling" ]; then
		scaling="$(read_freq 0)"
		i="$(freq_min $scaling)"
		o="$(freq_avg $scaling)"
		n="$(freq_max $scaling)"
		spawn : $scaling
		spawn : N="$i" minf="$minf"
		spawn : A="$o" avgf=
		spawn : X="$n" maxf="$maxf"
		scaling="$(( $maxf - ($maxf - $minf) / 40 ))"
		[ "$o" -ge "$scaling" ] ||
			rc="$TEST_FAILED"
		i=0; scaling=1
	fi

	# Waiting background stress-ng
	spawn wait "$v" >/dev/null ||:

	# Restoring saved values
	if [ -n "$noturbo" ]; then
		echo "$noturbo" >"$left"/intel_pstate/no_turbo ||:
	fi

	# Intel Performance and EBH again
	if [ "${#saved_bias[@]}" != 0 ]; then
		o=power/energy_perf_bias

		# Restoring saved values of EBH
		while [ "$i" -lt "${#saved_bias[@]}" ]; do
			write_cpu "${saved_bias[$i]}" "$i" "$o"
			i=$((1 + $i))
		done

		i=0
	fi

	# CPU Performance Scaling again
	if [ "${#saved_max[@]}" != 0 ]; then
		while [ "$i" -lt "${#saved_max[@]}" ]; do
			o=cpufreq/scaling_governor
			v="${saved_governors[$i]}"
			write_cpu "$v" "$i" "$o"
			o=cpufreq/scaling_min_freq
			write_cpu "${saved_min[$i]}" "$i" "$o"
			o=cpufreq/scaling_max_freq
			write_cpu "${saved_max[$i]}" "$i" "$o"

			if [ "$v" = userspace ]; then
				v="${saved_speed[$i]}"
				o=cpufreq/scaling_setspeed
				! have_cpu_var "$i" "$o" ||
				[ "$v" = "<unsupported>" ] ||
					write_cpu "$v" "$i" "$o"
			fi

			i=$((1 + $i))
		done
	fi

	# Showing the state for the last time
	spawn cpupower frequency-info |tee -a -- "$logfile"

	return "${rc:-$TEST_PASSED}"
}

have_cpu_var()
{
	[ -r "$left/cpu$1/$2" ]
}

read_cpu_var()
{
	head -n1 -- "$left/cpu$1/$2"
}

read_freq()
{
	local v i=0
	local badv="${1-99999999999}"
	local r=cpufreq/cpuinfo_cur_freq

	have_cpu_var 0 "$r" ||
		r=cpufreq/scaling_cur_freq

	while [ "$i" -lt "$n_cores" ]; do
		v="$(read_cpu_var "$i" "$r" 2>/dev/null || echo "$badv")"
		printf " %s" "$v"
		i=$((1 + $i))
	done
}

save_cpu_array()
{
	local v arr="$1" idx="$2" p="$3"

	have_cpu_var "$idx" "$p" ||
		return 1
	v="$(read_cpu_var "$idx" "$p")"
	eval "${arr}[$idx]=\"$v\""
}

write_cpu()
{
	echo "$1" >"$left/cpu$2/$3" ||:
}

freq_min()
{
	local minv="$1"; shift

	while [ "$#" != 0 ]; do
		[ "$minv" -le "$1" ] ||
			minv="$1"
		shift
	done

	printf "%s" "$minv"
}

freq_max()
{
	local maxv="$1"; shift

	while [ "$#" != 0 ]; do
		[ "$maxv" -ge "$1" ] ||
			maxv="$1"
		shift
	done

	printf "%s" "$maxv"
}

freq_avg()
{
	local sumv=0

	while [ "$#" != 0 ]; do
		sumv="$(( $sumv + $1 ))"
		shift
	done

	printf "%s" "$(( $sumv / $n_cores ))"
}

