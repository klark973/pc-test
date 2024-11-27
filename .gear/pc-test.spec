%define _unpackaged_files_terminate_build 1

%ifarch %e2k %mips riscv64
#shellcheck is not available on these architectures
%def_disable check
%endif

Name: pc-test
Version: 2.1.2
Release: alt2

Summary: PC Test Suite
Group: System/Configuration/Hardware
License: GPLv3+

BuildArch: noarch

Url: https://github.com/klark973/pc-test
Source: %name-%version.tar
AutoReq: noshell, noshebang

%{!?_disable_check:BuildRequires: shellcheck}

# Strict dependencies inside rootfs or on installation media
Requires: coreutils util-linux rpm apt apt-repo su sudo
Requires: bash update-kernel pciutils usbutils iproute2

# Other optional and essential dependencies.
# See /usr/libexec/pc-test/steps/upgrade.sh
# and /usr/libexec/pc-test/steps/install.sh
# for more details.
#
#Requires: inxi
#Requires: dialog
#Requires: yad
#Requires: fwupd
#Requires: lsscsi
#Requires: libibverbs-utils
#Requires: hdparm
#Requires: rfkill
#Requires: lsblk
#Requires: stress-ng
#Requires: cpupower
#Requires: eject
#Requires: sos
#Requires: system-report
#Requires: iputils
#Requires: iperf3
#Requires: acpica
#Requires: dmidecode
#Requires: smartmontools
#Requires: numactl
#Requires: squashfs-tools
#Requires: htop
#Requires: ipmitool
#Requires: alsa-utils
#Requires: aplay
#Requires: bluez
#Requires: upower
#Requires: xrandr
#Requires: /usr/bin/glxinfo
#Requires: kamoso
#Requires: vlc
#Requires: cheese
#Requires: xdotool
#Requires: wmctrl
#Requires: icon-theme-adwaita
#Requires: sound-theme-freedesktop
#Requires: fprintd
#Requires: pcsc-lite-ccid
#Requires: libpcsclite
#Requires: pcsc-tools
#Requires: opensc
#Requires: pcsc-lite
#Requires: fio
#Requires: glmark2
#Conflicts: openct
#Conflicts: pcsc-lite-openct
#Conflicts: libopenct

Packager: Leonid Krivoshein <klark@altlinux.org>

%description
Computers and servers test suite special for ALT Linux.
It supports all products, based on p9, p10, c9f1, c9f2,
c10f1 stable branches and Sisyphus-based regular builds.

%package doc
Summary: PC Test Suite documentation
Group: Documentation
BuildArch: noarch
AutoReq: noshell, noshebang

%description doc
Documentation and screenshoots for PC Test Suite.

%prep
%setup -q
%autopatch -p1

%build
chmod 0755  ".%_bindir/%name" \
	    "./usr/libexec/%name/resume.sh" \
	    "./usr/libexec/%name/launcher.sh"
cat >"./usr/libexec/%name/version.sh" <<EOF
# Auto-generated by the build system, do not edit directly!
#
readonly PCTEST_VERSION="%version"
readonly PCTEST_BUILD_DATE="$(date '+%%Y%%m%%d')"

EOF

%install
mkdir -p -m 0755 -- "%buildroot"
cp -aRf etc usr var "%buildroot/"

%post
# This is necessary to update the settings of older versions
a="^(# Allow \\w+ to execute) %_bindir/%name without a password$"
b="\\1 %name and dmesg"
sed -i -E "s|$a|$b|g" /etc/sudoers
a="^(\\w+ ALL=\\(ALL:ALL\\) NOPASSWD: %_bindir/%name)$"
b="\\1,$(which dmesg)"
sed -i -E "s|$a|$b|g" /etc/sudoers

%check
./check-scripts.sh

%files
%config(noreplace) %_sysconfdir/%name.conf
%_bindir/%name
/usr/libexec/%name
/usr/share/applications/%name.desktop
%_localstatedir/%name
%ghost %_logdir/%name.log

%files doc
%doc img html CHANGELOG.md LICENSE README.md

%changelog
* Thu Nov 28 2024 Leonid Krivoshein <klark@altlinux.org> 2.1.2-alt2
- Fixed:
  + add 15 sec timeout for slow Wi-Fi connections
  + do not check monitors for express testing
  + add and increase timeouts between operations

* Wed Jun 26 2024 Leonid Krivoshein <klark@altlinux.org> 2.1.2-alt1
- Added:
  + ability to reset subtest results
  + possibility to retest a previously completed test
  + collect PulseAudio and PipeWire configuration
- Fixed:
  + now all pc-test results are also saved
  + pack input data into gzip archives safer
  + show and save pc-test version earlier

* Sun Jun 16 2024 Leonid Krivoshein <klark@altlinux.org> 2.1.1-alt1
- Added:
  + CPU Performance Scaling modes test according to section 10.1
  + an express test according to section 9
  + possibility of manual testing
  + testing methodology v2.1 (HTML5) and Changelog
  + ability to use personal settings by the regular user
  + automatic OS updates are now disabled during testing
  + ability to show subtest results
  + many improvements in logging output
- Fixed:
  + fix to not skip glmark test on ALT SP Server
  + fix a very strange fault when saving status
  + fix to reload en_US messages correctly

* Sun May 05 2024 Leonid Krivoshein <klark@altlinux.org> 2.1.0-alt5
- Initial build for Sisyphus.

