###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###########################################
### The first part of the system update ###
###########################################

number=5.2
en_name="System and kernel update"
ru_name="Обновление системы и ядра"

altsp_mirrors=(
	http://update.altsp.su/pub/distributions/ALTLinux
	ftp://update.altsp.su/pub/distributions/ALTLinux
)

public_mirrors=(
	http://ftp.altlinux.org/pub/distributions/ALTLinux
	ftp://ftp.altlinux.org/pub/distributions/ALTLinux
	rsync://ftp.altlinux.org/ALTLinux
	http://mirror.yandex.ru/altlinux
	ftp://mirror.yandex.ru/altlinux
	rsync://mirror.yandex.ru/altlinux
	http://mirror.cs.msu.ru/alt
	rsync://mirror.cs.msu.ru/alt
	http://mirror.datacenter.by/pub/ALTLinux
	ftp://mirror.datacenter.by/pub/ALTLinux
	rsync://mirror.datacenter.by/ALTLinux
	http://ftp.heanet.ie/mirrors/ftp.altlinux.org
	ftp://ftp.heanet.ie/mirrors/ftp.altlinux.org
	rsync://ftp.heanet.ie/mirrors/ftp.altlinux.org
	http://distrib-coffee.ipsl.jussieu.fr/pub/linux/altlinux
	ftp://distrib-coffee.ipsl.jussieu.fr/pub/linux/altlinux
	rsync://distrib-coffee.ipsl.jussieu.fr/pub/linux/altlinux
)

testcase()
{
	local try rc=0 packages=

	[ -z "$update_apt_lists" ] ||
		setup_apt_sources
	spawn apt-repo |
		tee -a -- "$logfile"
	spawn apt-get update

	for try in 1 2 3; do
		[ -z "$dist_upgrade" ] ||
		[ "$repo" != Sisyphus ] ||
		is_pkg_installed usrmerge-hier-convert ||
		! is_pkg_available usrmerge-hier-convert ||
			spawn apt-get install -y usrmerge-hier-convert || rc="$?"
		[ -z "$dist_upgrade" ] ||
			spawn apt-get dist-upgrade -y || rc="$?"
		[ -z "$update_kernel" ] ||
			spawn update-kernel -f || rc="$?"
		[ "$rc" != 0 ] ||
			break
		rc="${L100-Try #%s/3 of a system update has been failed}"
		printf "${CLR_ERR}${rc}${CLR_NORM}...\n" "$try" |
			tee -a -- "$logfile"
		[ "$try" != 3 ] ||
			break
		sleep 2
		rc=0
	done

	# On ALT SP v8.2/c9f1 only
	if [ -n "$update_apt_lists" ]; then
		if [ -n "$have_altsp" ] && [ "$repo" = c9f1 ]; then
			spawn rm -f /etc/apt/preferences
			spawn apt-get update
		fi
	fi

	# Core packages must be installed before setup.
	# NOTE: yad absent in sisyphus_riscv64 for now.
	#
	is_pkg_installed inxi ||
		packages=inxi
	if [ -n "$have_xorg" ] &&
	   [ -n "${DISPLAY-}" ] &&
	   is_pkg_available yad
	then
		is_pkg_installed yad ||
			packages="$packages yad"
	else
		is_pkg_installed dialog ||
			packages="$packages dialog"
	fi
	if [ -n "$packages" ]; then
		spawn apt-get install -y -- $packages || rc="$?"
	fi
	if [ "$rc" != 0 ]; then
		rc="$TEST_FAILED"
	fi

	# ALT SP specific tweak
	if [ -n "$have_altsp" ] && has_binary integalert; then
		spawn integalert fix ||:
	fi

	# Reboot is required only after real system update
	if [ -n "$dist_upgrade" ] || [ -n "$update_kernel" ]; then
		system_restart $rc
	fi

	return $rc
}

setup_apt_sources()
{
	local url=

	# Setting the replacement URL
	if [ -n "$local_url" ]; then
		url="$local_url"
	elif [ -n "$local_mirror" ]; then
		setup_network_mirror
	elif [ "${#local_media_labels[@]}" != 0 ]; then
		setup_external_media
	elif [ -n "$repodate" ] && [ -z "$have_altsp" ]; then
		url="http://ftp.altlinux.org/pub/distributions/archive"

		case "$repo" in
		Sisyphus)
			url="$url/sisyphus/date"
			;;
		p9|p10|p11)
			url="$url/$repo/date"
			;;
		*)	url=
			;;
		esac

		# Using specified archive only
		if [ -n "$url" ]; then
			write_sources
			return 0
		fi
	fi

	# Are changes needed to the list of APT-sources?
	if [ -n "$have_altsp" ] && [ "$repo" = c9f2 ] &&
	   [ -z "$url" ] && apt-repo |grep -qsE -- '^rpm cdrom:'
	then
		# No, we updating ALT SP v8.4/c9f2 via Internet
		spawn apt-repo rm all cdroms
		spawn apt-repo
		spawn apt-get update
		spawn apt-get dist-upgrade -y
		spawn rpm --eval %_priority_distbranch
		spawn rpm -q apt-conf-branch
	elif [ "$(apt-repo |wc -l)" = 0 ]; then
		# Yes, we have an empty list of APT-sources
		write_sources
	elif ! apt-repo |grep -qsvE -- '^rpm cdrom:' &&
		apt-repo |grep -qsE -- '^rpm cdrom:'
	then
		# Yes, we only have one repository on the installation media
		write_sources
	elif [ -n "$url" ]; then
		# Yes, we need to replace public URLs with specified ones
		replace_mirror
	fi

	# On ALT SP v8.2/c9f1 only
	if [ -n "$have_altsp" ] && [ "$repo" = c9f1 ]; then
		cat >/etc/apt/preferences <<-EOF
		Package: *
		Pin: release c=classic
		Pin-Priority: 1001
		EOF
	fi
}

setup_network_mirror()
{
	local msg dirp=

	dirp="$(echo "$local_mirror" |awk '{print $2;}')"

	spawn mkdir -p -- "$dirp"
	grep -qs -- "$local_mirror" /etc/fstab ||
		printf "%s\n" "$local_mirror" >>/etc/fstab
	spawn mount -- "$dirp" 2>/dev/null ||:

	[ -z "$mirror_subdir" ] ||
		dirp="$dirp/$mirror_subdir"
	[ -d "$dirp/$repo/noarch/base" ] ||
		fatal F11 "Couldn\'t connect to server with the local mirror!"
	msg="${L101-Server with the local mirror is connected}"
	printf "$msg: ${CLR_BOLD}%s${CLR_NORM}\n\n" "$repo" |
		tee -a -- "$logfile"
	url="$dirp"
}

setup_external_media()
{
	local label msg dirp=

	for label in "${local_media_labels[@]}"; do
		dirp="$local_media_base/$label"

		if mountpoint -q -- "$dirp"; then
			[ -z "$local_media_check" ] ||
				dirp="$dirp/$local_media_check"
			[ ! -d "$dirp/$repo/noarch/base" ] ||
				break
		fi

		dirp=
	done

	[ -n "$dirp" ] ||
		fatal F10 "External media with the mirror is not connected!"
	msg="${L102-External media with the mirror is connected}"
	printf "$msg: ${CLR_BOLD}%s${CLR_NORM}\n\n" "$label" |
		tee -a -- "$logfile"
	url="$dirp"
}

write_sources()
{
	local mirror=
	local arepo=1
	local archive=
	local vendor=cert8
	local first=classic
	local branch="$repo/branch"
	local fmt="rpm [%s] %s %s/%s %s\n"

	if [ -n "$url" ]; then
		if [ "${url:0:1}" = / ]; then
			url="file:$url"
			branch="$repo"
			mirror=1
		elif [ -n "$repodate" ] && [ -z "$have_altsp" ]; then
			branch="${repodate//\-/\/}"
			archive=1
		fi
	elif [ -n "$have_altsp" ]; then
		url="${altsp_mirrors[0]}"
	else
		url="${public_mirrors[0]}"
	fi

	case "$repo" in
	Sisyphus)
		case "$archname" in
		mipsel|riscv64|loongarch64)
			[ -n "$mirror" ] ||
				branch="ports/$archname/$repo"
			vendor="sisyphus-$archname"
			archive=
			;;
		*)	# Primary architectures
			[ -n "$archive" ] ||
				branch="$repo"
			vendor=alt
			;;
		esac
		arepo=
		;;

	p10)	# Platform 10
		first="classic gostcrypto"
		vendor="$repo"
		;;

	p9)	# Platform 9
		case "$archname" in
		mipsel)
			[ -n "$mirror" ] ||
				branch="ports/$archname/$repo"
			vendor="$repo-$archname"
			archive=
			;;
		*)	vendor="$repo"
			;;
		esac
		;;

	c10f1)	# ALT SP v10.1 (Mar 2023)
		[ -n "$mirror" ] ||
			branch=c10f/branch
		first="classic gostcrypto"
		;;

	c9f2)	# ALT SP v8.4 (Dec 2021)
		[ -n "$mirror" ] ||
			branch=CF2/branch
		;;

	c9f1)	# ALT SP v8.2 (Dec 2020)
		[ -n "$mirror" ] ||
			branch=c9f1/branch
		;;
	esac

	spawn apt-repo rm all

	# See apt-conf-branch and altlinux-repos packages for more details
	( printf "$fmt" "$vendor" "$url" "$branch" "$archname" "$first"
	  [ "$archname" != x86_64 ] || [ -z "$arepo" ] ||
		 printf "$fmt" "$vendor" "$url" "$branch" x86_64-i586 classic
	  printf "$fmt" "$vendor" "$url" "$branch" noarch classic
	) >>/etc/apt/sources.list
}

replace_mirror()
{
	local u n tmpf mirror=
	local first optional addr junk

	[ "${url:0:1}" != / ] ||
		mirror=1
	tmpf="$(spawn mktemp -qt -- "$progname-XXXXXXXX.tmp")"

	spawn apt-repo |tee -- "$tmpf"
	spawn apt-repo rm all

	while read -r first optional addr junk; do
		if [ "${optional:0:1}" != '[' ]; then
			junk="$addr $junk"
			addr="$optional"
			optional=
		fi

		for u in "${altsp_mirrors[@]}" "${public_mirrors[@]}"; do
			n="${#u}"

			if [ "${addr:0:$n}" = "$u" ]; then
				addr="${url}${addr:$n}"
				[ -z "$mirror" ] ||
					addr="file:${addr//\/branch\//\/}"
				break
			fi
		done

		[ -z "$mirror" ] ||
			junk="${junk//branch\//}"
		printf "%s" "$first"
		[ -z "$optional" ] ||
			printf " %s" "$optional"
		printf " %s %s\n" "$addr" "$junk"
	done <"$tmpf" >>/etc/apt/sources.list

	spawn rm -f -- "$tmpf"
}

