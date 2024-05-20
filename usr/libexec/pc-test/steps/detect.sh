###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

###############################
### Hardware auto-detection ###
###############################

number=5.3
en_name="Automatic hardware discovery"
ru_name="Определение конфигурации оборудования"

testcase()
{
	local i=0 tmpf=/sys/class/dmi/id

	# PC Type
	[ -d "$tmpf" ] ||
		tmpf=/sys/devices/virtual/dmi/id
	[ ! -r "$tmpf"/chassis_type ] ||
		read -r i <"$tmpf"/chassis_type ||:
	case "$i" in
	3|4|5|6|7|15|16|24|36)
		pctype=Personal
		;;
	8|9|10|14)
		pctype=Notebook
		;;
	17|22|23|28|29)
		pctype=Server
		;;
	13)	pctype=Monoblock
		;;
	30)	pctype=Tablet
		;;
	31)	pctype=Convertible
		;;
	*)	if LANG=C lscpu |grep -qs 'Hypervisor vendor:'; then
			pctype=Virtual
		else
			pctype=Computer
		fi
		;;
	esac

	# Default computer name
	if [ -z "$compname" ]; then
		compname="$(head -n1 -- "$tmpf"/product_name 2>/dev/null |
				tr -d ' ' |sed -e 's/[\(\),].*$//')"
		[ -n "$compname" ] ||
			compname="$(head -n1 -- "$tmpf"/board_name 2>/dev/null |
					tr -d ' ' |sed -e 's/[\(\),].*$//')"
		[ -n "$compname" ] ||
			compname="$pctype-$archname"
		compname="${compname}-${distro}${have_altsp:+-cert}-${repo}"
	fi

	# Collecting information about hardware components
	tmpf="$(spawn mktemp -qt -- "$progname-XXXXXXXX.tmp")"

	# Whole Disk Drives
	for i in $(ls /sys/block/) _; do
		case "$i" in
		loop[0-9]*|ram[0-9]*|sr[0-9]*|dm-[0-9]*|md[0-9]*|_)
			continue
			;;
		esac
		[ -b "/dev/$i" ] ||
			continue
		[ ! -r "/sys/block/$i/ro" ] ||
		[ "$(head -n1 "/sys/block/$i/ro")" = 0 ] ||
			continue
		[ ! -d "/sys/block/$i/slaves" ] ||
		[ -z "$(ls -1 "/sys/block/$i/slaves/")" ] ||
			continue
		[ ! -d "/sys/block/$i/holders" ] ||
		[ -z "$(ls -1 "/sys/block/$i/holders/")" ] ||
			continue
		drives="$drives $i"
	done

	# MD RAID's separately
	if [ -z "$drives" ]; then
		for i in $(ls /sys/block/) _; do
			case "$i" in
			md[0-9]*|_)
				;;
			*)	continue
				;;
			esac
			[ -b "/dev/$i" ] ||
				continue
			drives="$drives $i"
		done
	fi

	# Removing space at the start of string
	[ -z "$drives" ] || drives="${drives:1}"

	# Infiniband/RDMA
	spawn lspci >"$tmpf"
	if grep -qsw RDMA "$tmpf" ||
	   grep -qsiw infiniband "$tmpf"
	then
		infb_test=1
	fi

	# Sound Cards
	if spawn inxi -A -c0 |grep -qs ' Device-1: '; then
		sound_test=1
	fi

	# NUMA Technology
	if [ "$(spawn lscpu --parse=NODE |
		grep -sE '^[0-9]' |
		sort -u |wc -l)" -gt 1 ]
	then
		numa_test=1
	fi

	# IPMI Management: default for servers and blade platforms
	if [ "$pctype" = Server ]; then
		ipmi_test=1
	fi

	# Web-camera: testing inpossible when these modules are not loaded
	if grep -qsE '^(uvcvideo |gspca_|em28xx)' /proc/modules; then
		webcam_test=1
	fi

	# Power Management by console: battery systems only
	if [ -z "$have_xorg" ] || [ -z "${DISPLAY-}" ]; then
		if spawn inxi -B -c0 |grep -qs ' ID-1: '; then
			power_test=1
		fi
	fi

	# Fingerprint Scanner: only some USB devices are listed
	spawn lsusb |cut -f6- -d' ' |grep -vE '^1d6b:000' >"$tmpf"
	if grep -qsw Fingerprint "$tmpf" ||
	   grep -qsE '^298d:1010 ' "$tmpf" ||
	   grep -qsE '^1c7a:(0570|0571|0603) ' "$tmpf" ||
	   grep -qs ' Digital Persona U.are.U 4000' "$tmpf" ||
	   grep -qs ' UPEK TouchChip/Eikon Touch 300' "$tmpf" ||
	   grep -qs ' UPEK TouchStrip' "$tmpf" ||
	   grep -qs ' Elan MOC Sensors' "$tmpf" ||
	   grep -qs ' Veridicom 5thSense' "$tmpf" ||
	   grep -qs ' Synaptics Sensors' "$tmpf" ||
	   grep -qs ' AuthenTec AES16' "$tmpf" ||
	   grep -qs ' AuthenTec AES25' "$tmpf" ||
	   grep -qs ' AuthenTec AES26' "$tmpf" ||
	   grep -qs ' AuthenTec AES4000' "$tmpf" ||
	   grep -qs ' AuthenTec AES3500' "$tmpf" ||
	   grep -qs ' Validity VFS' "$tmpf"
	then
		fprnt_test=1
	fi

	# Bluetooth interface and devices
	if spawn inxi -E -c0 |grep -qs ' Device-1: '; then
		bluez_test=1
	fi

	# Smart-cards: opensc package may not be installed
	if has_binary opensc-tool; then
		spawn opensc-tool --list-readers |
			grep -qs 'No smart card readers found' ||
				scard_test=1
	fi

	# How many network interfaces do we have?
	for i in $(ls /sys/class/net/) _; do
		case "$i" in
		lo|_)	continue;;
		*)	ifaces="$ifaces $i";;
		esac
	done

	# Removing space at the start of string
	[ -z "$ifaces" ] || ifaces="${ifaces:1}"

	# Can we do an express test?
	cando_express_test && xprss_test=1 ||:

	# Removing temporary file
	spawn rm -f -- "$tmpf"

	# Settings
	write_config
	cat -- "$workdir"/STATE/settings.ini >detect.ini
	tmpf="\"${CLR_LC1}\" \$1 \"${CLR_BOLD}=${CLR_LC2}\" \$2 \"${CLR_NORM}\""
	cat -- "$workdir"/STATE/settings.ini |awk -F = "{print $tmpf;}"
}

cando_express_test()
{
	[ "$pctype" != Server ] && [ -n "$ifaces" ] ||
		return 1
	[ -n "$sound_test" ] && [ -n "$have_xorg" ] ||
		return 1
	[ -n "$have_mate" ] || [ -n "$have_kde5" ] || [ -n "$have_xfce" ] ||
		return 1
	spawn inxi -G -c0 |grep -qs ' Device-1: ' ||
		return 1
	spawn inxi -Gxx -c0 |grep -qs ' Monitor-1: ' ||
		return 1
	return 0
}

