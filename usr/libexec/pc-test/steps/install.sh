###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

########################################
### Second part of the system update ###
########################################

number=5.5
en_name="Installing additional software"
ru_name="Установка дополнительных программ"

testcase()
{
	local list pkg packages wconf= deinstall=

	# 8.1. Essential packages must be installed from an external repo
	list="hdparm system-report rfkill acpica dmidecode"
	list="$list lsblk smartmontools stress-ng cpupower"
	[ -z "$devel_test" ] ||
		list="$list sos eject"
	[ -z "$ifaces" ] ||
		list="$list iperf3"
	packages="$list"

	# Install MATE in ALT SP Server
	if [ -n "$install_mate" ]; then
		list="mate-default lightdm-gtk-greeter fonts-ttf-dejavu"
		[ -z "$xprss_test" ] && [ -z "$helpfile" ] ||
			list="$list firefox-esr"

		for pkg in $list; do
			if ! is_pkg_available "$pkg"; then
				install_mate=
				wconf=1
				break
			fi
		done

		if [ -n "$install_mate" ]; then
			for pkg in $list yad; do
				is_pkg_installed "$pkg" ||
					packages="$packages $pkg"
			done
			have_xorg=1
			have_mate=1
			wconf=1
		fi
	fi

	# 6. Hardware components firmware update. The package fwupd is
	# optional because it is not built for e2k and absent in p9_mipsel.
	# Also it works with UEFI-based platforms only.
	#
	if [ -n "$fwupd_test" ] && is_pkg_available fwupd; then
		is_pkg_installed fwupd ||
			packages="$packages fwupd"
	fi

	# 8.2.10. SCSI, SATA and AHCI hardware. The package lscssi is
	# optional because it is absent in sisyphus_riscv64 and p9_mipsel.
	#
	if ! is_pkg_installed lsscsi && is_pkg_available lsscsi; then
		packages="$packages lsscsi"
	fi

	# 10.2.3. Infiniband/RDMA
	if [ -n "$infb_test" ] && is_pkg_available libibverbs-utils; then
		is_pkg_installed libibverbs-utils ||
			packages="$packages libibverbs-utils"
	fi

	# 10.4. Sound Cards
	if [ -n "$sound_test" ] && is_pkg_available aplay; then
		if is_pkg_available alsa-utils; then
			is_pkg_installed alsa-utils ||
				packages="$packages alsa-utils"
			is_pkg_installed aplay ||
				packages="$packages aplay"
		fi
	fi

	# 10.7.2. Power Managment by console
	if [ -n "$power_test" ] && is_pkg_available upower; then
		[ -n "$have_xorg" ] || is_pkg_installed upower ||
			packages="$packages upower"
	fi

	# 10.8. NUMA Technology
	if [ -n "$numa_test" ]; then
		list="htop numactl squashfs-tools"

		for pkg in $list; do
			is_pkg_installed "$pkg" ||
			is_pkg_available "$pkg" ||
				numa_test=
		done

		if [ -z "$numa_test" ]; then
			numa_test=1
		else
			for pkg in $list; do
				is_pkg_installed "$pkg" ||
					packages="$packages $pkg"
			done
		fi
	fi

	# 10.9. IPMI Managment
	if [ -n "$ipmi_test" ] && is_pkg_available ipmitool; then
		is_pkg_installed ipmitool ||
			packages="$packages ipmitool"
	fi

	# Xorg with any DE
	if [ -z "$have_xorg" ] ||
	   [ -z "$install_mate" ] && [ -z "${DISPLAY-}" ]
	then
		webcam_test=
		v3d_test=
		wconf=1
	else
		# xrandr is a graphical tool. glxinfo provides by the same name
		# package (old versions) or by mesa-info package (new versions)
		# with /usr/bin/eglinfo and /usr/bin/es2_info utilities.
		# See also: 8.2.14 and 8.3.5.
		#
		if ! is_pkg_installed xrandr; then
			packages="$packages xrandr"
		fi
		if ! has_binary glxinfo; then
			packages="$packages /usr/bin/glxinfo"
		fi

		# Web-camera or Sound Card, see: 10.4.2.2 and 10.10.3
		if [ -n "$webcam_test" ] || [ -n "$sound_test" ]; then
			if [ -n "$have_kde5" ] && [ "$distro" = KWS ]; then
				pkg=kamoso
			elif [ "$distro" = SRV ]; then
				pkg=vlc
			else
				pkg=cheese
			fi
			if is_pkg_available "$pkg"; then
				is_pkg_installed "$pkg" ||
					packages="$packages $pkg"
			fi
		fi

		# 11.2. Graphics performance
		if [ -n "$v3d_test" ] && is_pkg_available glmark2; then
			is_pkg_installed glmark2 ||
				packages="$packages glmark2"
		fi
	fi

	# 10.10.7. Fingerprint Scanner
	if [ -n "$fprnt_test" ] && is_pkg_available fprintd; then
		is_pkg_installed fprintd ||
			packages="$packages fprintd"
	fi

	# 10.10.10. Bluetooth interface
	if [ -n "$bluez_test" ] && is_pkg_available bluez; then
		is_pkg_installed bluez ||
			packages="$packages bluez"
	fi

	# 10.10.12. Smart-cards
	if [ -n "$scard_test" ]; then
		list="pcsc-lite-ccid libpcsclite pcsc-tools opensc pcsc-lite"

		for pkg in $list; do
			if ! is_pkg_installed "$pkg"; then
				if ! is_pkg_available "$pkg"; then
					scard_test=
					wconf=1
					break
				fi
			fi
		done

		if [ -n "$scard_test" ]; then
			for pkg in $list; do
				if ! is_pkg_installed "$pkg"; then
					if is_pkg_available "$pkg"; then
						packages="$packages $pkg"
					fi
				fi
			done

			for pkg in openct pcsc-lite-openct libopenct; do
				if is_pkg_installed "$pkg"; then
					deinstall="$deinstall $pkg"
				fi
			done
		fi
	fi

	# 11.1. Disks subsystem performance
	if [ -n "$fio_test" ] && is_pkg_available fio; then
		is_pkg_installed fio ||
			packages="$packages fio"
	fi

	# 5. Removing packages
	[ -z "$deinstall" ] ||
		spawn apt-get remove --purge -y -- $deinstall
	spawn remove-old-kernels -f ||:
	spawn apt-get autoremove --purge -y ||:

	# 8.1. Installing packages
	spawn apt-get install -y -- $packages
	spawn apt-get autoremove --purge -y ||:
	spawn apt-get clean

	# Checking systemd support again
	if has_binary systemctl && has_binary journalctl; then
		[ -n "$have_systemd" ] ||
			wconf=1
		have_systemd=1
	fi

	# 10.2.3. Tweak for Infiniband/RDMA
	if [ -n "$infb_test" ] && is_pkg_installed libibverbs-utils; then
		list="ib_ipoib rdma_ucm ib_uverbs ib_umad"
		list="$list rdma_cm ib_cm ib_mad iw_cm"

		for pkg in $list; do
			if modinfo "$pkg" &>/dev/null; then
				echo "$pkg" >>/etc/modules
			fi
		done
	fi

	# 10.9. Tweak for IPMI Managment
	if [ -n "$ipmi_test" ] && has_binary ipmitool; then
		cat >>/etc/modules <<-EOF
		ipmi_msghandler
		ipmi_devintf
		ipmi_si
		EOF
	fi

	# 10.10.7. Tweak for Fingerprint Scanner
	if [ -n "$fprnt_test" ] && [ -n "$have_systemd" ]; then
		if is_pkg_installed fprintd; then
			spawn systemctl enable fprintd
		fi
	fi

	# 10.10.10. Tweak for Bluetooth interface
	if [ -n "$bluez_test" ] && [ -n "$have_systemd" ]; then
		if is_pkg_installed bluez; then
			spawn systemctl enable bluetooth
		fi
	fi

	# 10.10.12. Tweak for Smart-cards interface
	if [ -n "$scard_test" ] && [ -n "$have_systemd" ]; then
		if is_pkg_installed pcsc-lite; then
			spawn systemctl enable pcscd.service pcscd.socket
		fi
	fi

	# ALT SP Server 10 tweak after the MATE intstallation
	if [ -n "$install_mate" ] && [ -n "$have_systemd" ]; then
		spawn systemctl enable lightdm
		spawn systemctl set-default graphical.target
	fi

	# ALT SP specific tweak
	if [ -n "$have_altsp" ] && has_binary integalert; then
		spawn integalert fix ||:
	fi

	# Resetting systemd journal
	if [ -n "$have_systemd" ]; then
		spawn systemctl stop systemd-journald
		(set +f; rm -rf /var/log/journal/* ||:) 2>/dev/null
	fi

	# Saving new configuration and rebooting
	if [ -n "$wconf" ]; then
		write_config
		cat -- "$workdir"/STATE/settings.ini >install.ini
		wconf="\"${CLR_LC1}\" \$1 \"${CLR_BOLD}=${CLR_LC2}\" \$2 \"${CLR_NORM}\""
		cat -- "$workdir"/STATE/settings.ini |awk -F = "{print $wconf;}"
	fi
	system_restart
}

