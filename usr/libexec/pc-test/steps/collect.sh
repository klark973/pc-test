###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

##############################
### Collecting information ###
##############################

number=8.2
en_name="Collecting information about hardware"
ru_name="Сбор информации о системе и оборудовании"

testcase()
{
	local dev

	# Using POSIX output in some cases
	if [ -n "$username" ] && [ "$langid" != en ]; then
		export LANG=C
	fi

	# 8.2.1. inxi
	if [ -n "$colormode" ]; then
		spawn inxi -v8 -c2 |tee inxi.txt
	else
		spawn inxi -v8 -c2 >inxi.txt
	fi

	# 8.3.1. CPU + Motherboard
	spawn inxi -CM -c0 >inxi-CM.txt

	# 8.3.2. Memory
	spawn inxi -m -c0 >inxi-m.txt

	# 8.3.3. Disk drives
	spawn inxi -D -c0 >inxi-D.txt

	# 8.3.4. Graphics
	spawn inxi -G -c0 >inxi-G.txt

	# 8.2.2. sosreport
	if [ -n "$devel_test" ] && is_pkg_installed sos; then
		dev="$(spawn rpm -q sos --qf '%{VERSION}')"
		( set +f; rm -f /var/tmp/sosreport* ||: ) 2>/dev/null
		if [ "$(spawn rpmvercmp "$dev" 4.6.0)" -lt 0 ]; then
			spawn sosreport --batch --quiet --all-logs --no-report
			( set +f
			  mv -f /var/tmp/sosreport*.tar.xz \
				sosreport.tar.xz ||:
			  mv -f /var/tmp/sosreport*.tar.xz.md5 \
				sosreport.tar.xz.md5 ||:
			) 2>/dev/null
			if [ -s sosreport.tar.xz.md5 ]; then
				spawn cat sosreport.tar.xz.md5 |
					tee -a -- "$logfile"
			fi
		else
			# Since v4.6.0 sosreport command was deprecated and
			# repports will save to another directory by default
			#
			( export TMPDIR=/var/tmp
			  spawn sos report --batch --quiet --all-logs --no-report )
			( set +f
			  mv -f /var/tmp/sosreport*.tar.xz \
				sosreport.tar.xz ||:
			  mv -f /var/tmp/sosreport*.tar.xz.sha256 \
				sosreport.tar.xz.sha256 ||:
			  chmod 0644 sosreport.tar.xz* ||:
			) 2>/dev/null
			if [ -s sosreport.tar.xz ]; then
				spawn md5sum sosreport.tar.xz |
					tee -a -- "$logfile"
			fi
		fi
	fi

	# 8.2.3. system-report
	spawn pushd /var/tmp/ >/dev/null
	( set +f; rm -f sysreport* ||: ) 2>/dev/null
	spawn system-report
	spawn popd >/dev/null
	( set +f
	  mv -f /var/tmp/sysreport*.tar.xz sysreport.tar.xz ||:
	) 2>/dev/null
	if [ -s sysreport.tar.xz ]; then
		spawn md5sum sysreport.tar.xz |
			tee -a -- "$logfile"
	fi

	# 8.2.16. make-initrd bug-report
	if [ -n "$devel_test" ] && has_binary make-initrd; then
		spawn pushd /var/tmp/ >/dev/null
		( set +f; rm -f ./*bugreport* ||: ) 2>/dev/null
		if spawn make-initrd bug-report; then
			( set +f
			  mv -f make-initrd-bugreport-*.tar.bz2 \
				bugreport.tar.bz2 ||:
			) 2>/dev/null
		fi
		spawn popd >/dev/null
		if [ -s /var/tmp/bugreport.tar.bz2 ]; then
			spawn mv -f /var/tmp/bugreport.tar.bz2 ./
			spawn md5sum bugreport.tar.bz2 |
				tee -a -- "$logfile"
		fi
	fi

	# 8.2.4. acpidump
	spawn acpidump >acpi.dat

	# 8.2.5. lspci
	spawn lspci -nnk |tee lspci.txt

	# 8.2.6, 8.3.2. dmidecode
	spawn dmidecode >dmidecode.txt
	spawn dmidecode --type 19 |tee mem-info.txt

	# 8.2.7. lsusb
	spawn lsusb |tee lsusb.txt
	spawn lsusb -t |tee lsusb_hierarchy.txt

	# 8.2.8. lscpu
	spawn lscpu |tee lscpu.txt

	# 8.2.9. lsblk
	spawn lsblk -ft |tee lsblk.txt

	# 8.2.10. lsscsi
	if has_binary lsscsi; then
		spawn lsscsi -v |tee lsscsi.txt
		[ -s lsscsi.txt ] || spawn rm -f lsscsi.txt
	fi

	# Disk drives
	for dev in $drives _
	do
		# Skipping MD
		case "$dev" in
		md[0-9]*|_)
			continue
			;;
		esac

		# 8.2.11. smartctl
		spawn smartctl -a -- "/dev/$dev" >"smartctl-$dev.txt"

		# 10.5.1. Drive interface performance
		spawn sync && echo 3 >/proc/sys/vm/drop_caches
		spawn hdparm -t --direct -- "/dev/$dev" |tee "hdparm-$dev.txt"
	done

	# 8.2.12. rfkill
	spawn rfkill --output-all |tee rfkill.txt
	[ -s rfkill.txt ] || spawn rm -f rfkill.txt

	# 8.2.13. uname -a
	spawn uname -a |tee uname.txt

	# With Xorg/x11/Wayland only
	if [ -n "$have_xorg" ] && [ -n "${DISPLAY-}" ]
	then
		# 8.2.14. xrandr
		spawn xrandr >xrandr.txt

		# 8.3.5. GL/mesa-info
		spawn glxinfo >glxinfo.txt
		spawn grep 'direct rendering' glxinfo.txt |
			tee -a -- "$logfile"
		if [ -n "$devel_test" ]; then
			! has_binary es2_info ||
				spawn es2_info >es2_info.txt
			! has_binary eglinfo  ||
				spawn eglinfo >eglinfo.txt
		fi
	fi

	# 8.2.15. Elbrus only
	if [ -r /proc/bootdata ]; then
		spawn grep cache /proc/bootdata >e2k_cache.txt
	fi

	# 8.3.6. CD/DVD/Blu-ray features
	if [ -r /proc/sys/dev/cdrom/info ]; then
		if [ -n "$(sed -n -E 's/^drive name:\s+//p' \
					/proc/sys/dev/cdrom/info)" ]
		then
			spawn cat /proc/sys/dev/cdrom/info |
						tee dvd-info.txt
			if [ -n "$devel_test" ]; then
				spawn eject -vr |tee eject-vr.txt
				spawn sleep 2
				spawn eject -vt |tee eject-vt.txt
			fi
		fi
	fi
}

