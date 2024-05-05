###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

#####################################
### Preparing for a system update ###
#####################################

number=5.1
en_name="Preparing for a system update"
ru_name="Подготовка к обновлению системы"

testcase()
{
	local n v p lsm=
	local r=/etc/os-release

	# Checking IMA/EVM
	if [ "$(head -n1 /sys/kernel/security/evm 2>/dev/null ||:)" = 1 ]; then
		fatal F04 "First you need to disable %s!" IMA/EVM
	fi

	# Checking AppArmor
	if [ -d /sys/kernel/security/apparmor ]; then
		if has_binary aa-enabled; then
			[ "$(spawn aa-enabled)" != Yes ] || lsm=1
		else
			lsm=1
		fi
		if [ -n "$lsm" ]; then
			fatal F04 "First you need to disable %s!" AppArmor
		fi
	fi

	# Checking SELinux
	if [ -d /sys/kernel/security/selinux ] || [ -d /sys/fs/selinux ]; then
		if has_binary getenforce; then
			lsm="$(spawn getenforce |tr '[:upper:]' '[:lower:]')"
		elif has_binary sestatus; then
			lsm="$(spawn sestatus |sed -n -E 's/^Current mode://p')"
		else
			lsm=enforcing
		fi
		if [ "$lsm" != enforcing ]; then
			lsm=
		else
			fatal F04 "First you need to disable %s!" SELinux
		fi
	fi

	# 7.1. Non-informative kernel messages
	n="AER: (Corrected error message|Multiple Corrected error) received"
	if [ "$(spawn dmesg |grep -scE -- "$n")" -gt 9 ]; then
		fatal F05 "Use pcie_aspm=off, pci=nomsi or pci=noaer boot options!"
	fi

	# Determining hardware platform (CPU architecture)
	archname="$(spawn uname -m)"

	# Determining ALT Linux distro and repository
	[ -s "$r" ] && grep -qsE -- "^ID=altlinux" "$r" ||
		fatal F06 "ALT Linux or compatible distro is required!"
	n="$(sed -n -E 's/^NAME=//;s/^"//p' "$r" |sed -e 's/"$//' |
					tr '[:upper:]' '[:lower:]')"
	p="$(sed -n -E 's/^PRETTY_NAME=//;s/^"//p' "$r" |sed -e 's/"$//')"
	v="$(sed -n -E 's/^VERSION_ID=//p' "$r")"
	#
	case "$n" in
	"myoffice plus")
		distro=WS
		repo=p10
		;;
	"alt tonk")
		distro=WS
		;;
	*) # Generic way
		if [ -z "${n##*sisyphus*}" ] || [ -z "${p##*Regular*}" ]; then
			distro=REG
			repo=Sisyphus
		elif [ -z "${n##*starter*}" ] || [ -z "${p##*Starter*}" ]; then
			distro=SKIT
		elif [ -z "${n##*simply*}" ] || [ -z "${p##*Simply*}" ]; then
			distro=SL
		elif [ -z "${p##*Workstation K*}" ] ||
		     [ -z "${p##*K Workstation*}" ]
		then
			distro=KWS
		elif [ -z "${n##*workstation*}" ]; then
			distro=WS
		elif [ -z "${n##*education*}" ]; then
			distro=EDU
		elif [ -z "${n##*server-v*}" ] ||
		     [ -z "${p##*Virtualization Server*}" ]
		then
			distro=ASV
		elif [ -z "${n##*server*}" ]; then
			distro=SRV
		else
			fatal F07 "Unsupported distro: %s" "$p"
		fi
	esac
	#
	if [ -z "${n##*alt 8 sp*}" ] || [ -z "${n##*alt sp*}" ] ||
	   [ -z "${p##*ALT 8 SP*}" ] || [ -z "${p##*ALT SP*}" ] ||
	   [ -z "${n##*(cliff)}"   ] || [ -z "${p##*(cliff)}" ]
	then
		if [ "$distro" = WS ] || [ "$distro" = SRV ]; then
			have_altsp=1
		fi
	fi
	#
	if [ -z "$repo" ] && [ -n "$have_altsp" ]; then
		case "$v" in
		8.2)	repo=c9f1;;
		8.4)	repo=c9f2;;
		10)	repo=c10f1;;
		*)	fatal F08 "Unsupported certified distro: %s" "$p";;
		esac
	elif [ -z "$repo" ]; then
		case "$v" in
		9|9.*|p9|p9-mipsel)
			repo=p9
			;;
		10|10.*|p10)
			repo=p10
			;;
		*)	fatal F09 "Unsupported distro version: %s" "$p";;
		esac
	fi
	#
	distroname="$p"

	# Checking systemd support
	if has_binary systemctl && has_binary journalctl; then
		have_systemd=1
	fi

	# Checking xserver installation and desktop environment
	if [ -x /usr/bin/Xorg ] || [ -x /usr/bin/Xwayland ]; then
		have_xorg=1
	fi
	if is_pkg_installed kde5; then
		have_kde5=1
		have_xorg=1
	fi
	if is_pkg_installed mate-minimal ||
		is_pkg_installed mate-default ||
		is_pkg_installed mate-window-manager
	then
		have_mate=1
		have_xorg=1
	fi
	if is_pkg_installed xfce4-minimal ||
		is_pkg_installed xfce4-default
	then
		have_xfce=1
		have_xorg=1
	fi

	# Settings
	write_config
}

