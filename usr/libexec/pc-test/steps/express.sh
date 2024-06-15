###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

#######################################
### Express test of main components ###
#######################################

number=9
en_name="Express test of main components"
ru_name="Экспресс-тест основных компонентов"

pre()
{
	local p

	[ -n "$xprss_test" ] && [ -n "$have_xorg" ] && [ -n "$ifaces" ] ||
		return $TEST_SKIPPED
	[ -n "$have_mate" ] || [ -n "$have_kde5" ] || [ -n "$have_xfce" ] ||
		return $TEST_SKIPPED

	case "${XDG_CURRENT_DESKTOP-}" in
	KDE|MATE|XFCE)
		;;
	*)	return $TEST_SKIPPED
		;;
	esac

	spawn grep -qs ' Device-1: ' inxi-G.txt ||
		return $TEST_SKIPPED
	[ -n "${DISPLAY-}" ] && [ "${XDG_SESSION_TYPE-}" = x11 ] ||
		return $TEST_BLOCKED
	[ -n "$have_systemd" ] ||
		return $TEST_BLOCKED

	for p in yad xdg-open xdotool wmctrl pactl paplay notify-send; do
		has_binary "$p" ||
			return $TEST_BLOCKED
	done

	[ -s /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga ] &&
	[ -s /usr/share/icons/Adwaita/32x32/legacy/audio-volume-muted.png ] ||
		return $TEST_BLOCKED
	spawn ip route |grep -qsE '^default via ' ||
		return $TEST_BLOCKED

	return $TEST_ALLOWED
}

testcase()
{
	local idx random_video vsamples

	# shellcheck disable=SC2207
	vsamples=( $(< "/var/lib/$progname/vsamples.txt") )
	idx=$(( $RANDOM % ${#vsamples[@]} ))

	# Running an autotest
	if express_choice_form; then
		express_autotest || return "$?"
	else
		# Starting manual testing
		. "$libdir"/step-gui.sh

		random_video="https://youtu.be/${vsamples[$idx]}"
		spawn xdg-open "${local_video_sample:-$random_video}" 2>>"$xorglog" ||:
		form_gui "_экспресс_тест_основных_компонентов" || return "$?"
	fi

	return $TEST_PASSED
}

express_choice_form()
{
	local rc=0
	local autotime=
	local msg fld img=

	if [ -s ./EXPRESS-AUTOTEST ]; then
		rc="$(head -n1 ./EXPRESS-AUTOTEST)"
		return $rc
	fi

	msg="Before express testing, the computer will be turned off."
	msg="$msg To switch to manual testing, press the «Cancel»"
	msg="$msg button or the Esc key."

	fld="Don\'t forget to turn on the video recording and show"
	fld="$fld a close-up video of the computer model, interfaces"
	fld="$fld for connecting external monitors and audio devices."

	img=/usr/share/icons/Adwaita/48x48/legacy/system-shutdown.png

	[ ! -s "$img" ] && img="" ||
		img="--image=$img"
	[ -z "$batchmode" ] ||
		autotime="--timeout-indicator=bottom --timeout=15"
	spawn yad \
		--width=620 --height=150		\
		--borders=10 --center --on-top		\
		--window-icon=utilities-system-monitor	\
		$autotime $img				\
		--title="$(nls_title)"			\
		--text="${L260-$msg}"			\
		--form --field="${L261-$fld}":LBL	\
	2>>"$xorglog" || rc="$?"

	case "$rc" in
	0|70)	rc=0;;
	*)	rc=1;;
	esac

	printf "%s\n" "$rc" >./EXPRESS-AUTOTEST

	return $rc
}

express_autotest()
{
	local stepno brpid=""
	local sound_is_muted=1
	local rc="$TEST_PASSED"
	local class="" browser=""
	local sfile=./express.step

	# Ability to restart if any sub-test fails
	stepno="$(head -n1 -- "$sfile" 2>/dev/null ||:)"
	[ -n "$stepno" ] || stepno=1
	spawn : Express autotest step "#$stepno"

	# One-time initialization
	if [ "$stepno" -ge 2 ] && [ "$stepno" -le 5 ]; then
		express_autotest_init || {
			rc="$?"
			stepno=7
		}
	fi

	# Counting sub-test steps
	while [ "$stepno" -lt 7 ]; do
		printf "%s\n" "$stepno" >"$sfile"

		case "$stepno" in
		1) express_try_poweroff || {
			rc="$?"
			break
		   };;
		2) express_show_settings;;
		3) express_try_hibernate;;
		4) express_try_suspend  ;;
		5) express_additional_hw;;
		*) express_try_reboot   ;;
		esac

		stepno=$((1 + $stepno))
		spawn : Express autotest step "#$stepno"
	done

	if [ "$rc" = "$TEST_PASSED" ]; then
		if [ -s ./POWEROFF-FAILED  ] ||
		   [ -s ./HIBERNATE-FAILED ] ||
		   [ -s ./SUSPEND-FAILED   ] ||
		   [ -s ./NETWORK-FAILED   ] ||
		   [ -s ./WIFI-FAILED      ] ||
		   [ -s ./REBOOT-FAILED    ]
		then
			rc="$TEST_FAILED"
		elif [ ! -s ./SUSPEND-STARTED ] &&
		     [ ! -s ./HIBERNATE-STARTED ]
		then
			rc="$TEST_SKIPPED"
		fi
	fi

	express_show_results "$rc" |
		tee -a -- "$logfile"
	spawn rm -f -- "$sfile"

	return $rc
}

express_try_poweroff()
{
	local msg session

	if [ -s ./POWEROFF-STARTED ]; then
		express_save_date POWEROFF-FINISHED
		express_autotest_init ||
			return "$?"
		return $TEST_PASSED
	fi

	msg="${L259-Checking shutdown (Power OFF)}..."
	spawn notify-send "$(nls_title)" "$msg"
	spawn sleep 5
	msg="${L262-Shutting down...}"
	session="$(spawn loginctl session-status |head -n1 |cut -f1 -d' ')"
	printf "[${CLR_BOLD}%s${CLR_NORM}] ${CLR_ERR}%s${CLR_NORM}\n" \
		"$(date '+%T')" "$msg" |tee -a -- "$logfile" >&2
	express_save_date POWEROFF-STARTED

	if spawn systemctl -i poweroff; then
		spawn loginctl terminate-session "$session" ||:
		exit 0
	fi

	express_save_date POWEROFF-FAILED
}

express_autotest_init()
{
	local i keys=( Tab Tab m f )

	random_video="https://www.youtube.com/embed/${vsamples[$idx]}"
	random_video="${random_video}?autoplay=1&controls=1&enablejsapi=1"
	random_video="${random_video}&cc_load_policy=1&mute=1&rel=0"

	# First we read the DE settings
	if has_binary xdg-settings; then
		browser="$(spawn xdg-settings get default-web-browser ||:)"

		if [ ! -s /usr/share/applications/"$browser" ]; then
			browser=
		else
			# shellcheck disable=SC2002
			browser="$(cat /usr/share/applications/"$browser" |
					sed -n -E 's/^Exec=//p' |
					head -n1 |cut -f1 -d' ')"
			[ -z "$browser" ] ||
			[ -x "$browser" ] ||
			has_binary "$browser" ||
				browser=
		fi
	fi

	# Using one of the installed browsers as fallback
	if [ -z "$browser" ]; then
		for i in firefox chromium chromium-gost \
			 yandex-browser-stable yandex-browser
		do
			if has_binary "$i"; then
				browser="$i"
				break
			fi
		done
	fi

	spawn : browser="$browser"

	case "$browser" in
	"")	return $TEST_BLOCKED
		;;
	chromium*|yandex-browser*)
		class=chromium
		;;
	firefox)
		browser="$browser --new-tab"
		class=firefox
		;;
	esac

	spawn : browser class="$class"

	# Checking mute settings once
	spawn env LANG=C LC_ALL=C pactl list sinks |
		grep -qsE '^\s+Mute: yes' ||
			sound_is_muted=
	express_set_audio_volume 50

	# Opening a browser window with the selected video
	spawn : Running $browser "${local_video_sample:-$random_video}"
	$browser "${local_video_sample:-$random_video}" 2>>"$xorglog" & brpid="$!"

	if [ -z "$local_video_sample" ]; then
		i="The video starts without sound, no need to press anything!"
		spawn notify-send "$(nls_title)" "${L254-$i}"
	fi

	i=0
	spawn sleep 15

	# With a local video sample, we
	# only maximize the browser window
	if [ -n "$local_video_sample" ]; then
		spawn xdotool search --sync --onlyvisible --class "$class" \
			windowactivate key F11 sleep 0.3 keyup F11 sleep 0.5
		i="${#keys[@]}"
	fi

	# Unmuting sound in YouTube player
	# and expanding window to full screen
	while [ "$i" -lt "${#keys[@]}" ]; do
		spawn xdotool search --sync --onlyvisible \
			--class "$class" windowactivate \
			key "${keys[$i]}" sleep 0.3 \
			keyup "${keys[$i]}" sleep 0.5
		i=$((1 + $i))
	done

	return $TEST_PASSED
}

express_set_audio_volume()
{
	local i body volume="$1"
	local sound level icon

	if [ "${XDG_CURRENT_DESKTOP-}" = XFCE ]; then
		level=
	elif [ "$volume" -ge 75 ]; then
		level=high
	elif [ "$volume" -ge 35 ]; then
		level=medium
	elif [ "$volume" = 0 ]; then
		level=muted
	else
		level=low
	fi

	if [ -n "$level" ]; then
		body="$(spawn env LANG=C LC_ALL=C pactl list sinks |
			sed -n -E 's/^\s+Description: //p' |
			head -n1)"
		icon="/usr/share/icons/Adwaita/32x32/legacy/audio-volume-$level.png"
	fi

	if [ "$volume" = 0 ]; then
		spawn pactl set-sink-mute 0 1 ||:
		sound_is_muted=1

		if [ -n "$level" ]; then
			body="${body}\n${L250-Sound muted}"
			express_notify "${L251-Mute}" "$body"
		fi
	else
		if [ -n "$sound_is_muted" ]; then
			spawn pactl set-sink-mute 0 0 ||:
			sound_is_muted=
		fi

		sound=/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga

		if spawn pactl set-sink-volume 0 "${volume}%"; then
			for i in 1 2 3 4 5; do
				spawn paplay "$sound" ||:
			done

			if [ -n "$level" ]; then
				body="${body}\n${L252-Level}: ${volume}%"
				express_notify "${L253-Volume level}" "$body"
			fi
		fi
	fi
}

express_notify()
{
	local title="$1" text="$2"
	local geometry="330x50-50-50"

	[ "${XDG_CURRENT_DESKTOP-}" != MATE ] ||
		geometry="330x50-50+50"
	spawn yad \
		--geometry="$geometry"		\
		--fixed				\
		--timeout=3			\
		--timeout-indicator=bottom	\
		--no-buttons			\
		--undecorated			\
		--on-top			\
		--skip-taskbar			\
		--no-escape			\
		--image="$icon"			\
		--text="$title\n\n$text"	\
	2>>"$xorglog" ||:
}

express_show_settings()
{
	local pid=
	local prog=
	local args=
	local sound

	case "${XDG_CURRENT_DESKTOP-}" in
	KDE)	prog=systemsettings; args=kcm_kscreen;;
	MATE)	prog=mate-display-properties;;
	XFCE)	prog=xfce4-display-settings;;
	esac

	spawn : Screen configuration
	spawn xrandr --listactivemonitors |
		tee -a -- "$logfile"
	spawn xrandr |
		grep -svE '^(Screen |   )' |
		sed -e 's/ (.*$//g' |
		grep -svE ' disconnected$' |
		tee -a -- "$logfile"

	if [ -n "$prog" ] && has_binary "$prog"; then
		[ -z "$args" ] ||
			prog="$prog $args"
		spawn : Running $prog
		$prog 2>>"$xorglog" & pid="$!"

		spawn sleep 15

		( spawn kill -TERM "$pid" ||
			spawn kill -KILL "$pid" ||:
		  spawn wait "$pid" ||:
		) 2>/dev/null
	fi

	spawn sleep 30
	sound=/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga
	args="$(xrandr |sed -n '/ connected primary /p' |head -n1 |cut -f1 -d' ')"

	if [ -n "$args" ]; then
		spawn : Screen brightness

		for pid in 0.25 0.33 0.5 0.75 1.5 1.25 1; do
			spawn xrandr --output "$args" --brightness "$pid" &&
				spawn paplay "$sound" || continue
			spawn sleep 2
		done
	fi

	spawn : Volume level
	express_set_audio_volume 0
	spawn sleep 15
	express_set_audio_volume 75
	spawn sleep 15
	express_set_audio_volume 25
	spawn sleep 15

	# Normalizing a window with the selected video
	if [ -n "$local_video_sample" ]; then
		spawn xdotool search --sync --onlyvisible --class "$class" \
			windowactivate key F11 sleep 0.3 keyup F11 sleep 0.5
	else
		spawn xdotool search --sync --onlyvisible --class "$class" \
			windowactivate key f sleep 0.3 keyup f sleep 0.5
	fi

	# Maximizing a window with the selected video
	args="$(spawn xdotool search --sync --class "$class" getwindowpid |head -n1)"
	args="$(spawn wmctrl -l -p |grep -sE "\s+$args\s+" |head -n1 |cut -f1 -d' ')"
	spawn wmctrl -i -r "$args" -b add,maximized_horz,maximized_vert ||:
}

express_try_hibernate()
{
	local msg f="^\s+Loaded: masked "
	local s="systemd-hibernate.service"

	if systemctl status hibernate.target |grep -qsE -- "$f"; then
		spawn : hibernate.target is masked, skipping
		return 0
	fi

	if [ -s ./HIBERNATE-STARTED ]; then
		express_save_date HIBERNATE-FAILED
		spawn sleep 15
	else
		msg="${L257-Checking ACPI/S4 (Hibernation)}..."
		spawn notify-send "$(nls_title)" "$msg"
		spawn sleep 5
		express_save_date HIBERNATE-STARTED

		if ! spawn systemctl -i hibernate; then
			express_save_date HIBERNATE-FAILED
		else
			express_pause
			express_save_date HIBERNATE-FINISHED
			spawn systemctl status systemd-hibernate.service |
				tee h.status
			spawn sudo dmesg -H -P --color=always |
				gzip -9qnc >h.dmesg.gz
			express_resume_player
		fi
	fi

	if [ ! -f ./HIBERNATE-FAILED ]; then
		if grep -qs -- " $s: Succeeded" h.status ||
		   grep -qs -- " Finished Hibernate" h.status ||
		   grep -qs -- " System returned from sleep " h.status ||
		   grep -qs -- " $s: Deactivated successfully" h.status
		then
			spawn sleep 15
			spawn : Volume level after hibernate
			express_set_audio_volume 100
			spawn sleep 15
			express_set_audio_volume 50
			spawn sleep 15
			return 0
		fi
	fi

	[ ! -s ./HIBERNATE-FINISHED ] ||
		mv -f ./HIBERNATE-FINISHED ./HIBERNATE-FAILED
	return 0
}

express_try_suspend()
{
	local msg f="^\s+Loaded: masked "
	local s="systemd-suspend.service"

	if systemctl status suspend.target |grep -qsE -- "$f"; then
		spawn : suspend.target is masked, skipping
		return 0
	fi

	if [ -s ./SUSPEND-STARTED ]; then
		express_save_date SUSPEND-FAILED
		spawn sleep 15
	else
		msg="${L258-Checking ACPI/S3 (Suspend to RAM)}..."
		spawn notify-send "$(nls_title)" "$msg"
		spawn sleep 5
		express_save_date SUSPEND-STARTED

		if ! spawn systemctl -i suspend; then
			express_save_date SUSPEND-FAILED
		else
			express_pause
			express_save_date SUSPEND-FINISHED
			spawn systemctl status systemd-suspend.service |
				tee s.status
			spawn sudo dmesg -H -P --color=always |
				gzip -9qnc >s.dmesg.gz
			express_resume_player
		fi
	fi

	if [ ! -f ./SUSPEND-FAILED ]; then
		if grep -qs -- " $s: Succeeded" s.status ||
		   grep -qs -- " Finished Suspend" s.status ||
		   grep -qs -- " Finished System Suspend" s.status ||
		   grep -qs -- " System returned from sleep " s.status ||
		   grep -qs -- " $s: Deactivated successfully" s.status
		then
			spawn sleep 15
			spawn : Volume level after suspend
			express_set_audio_volume 25
			spawn sleep 15
			express_set_audio_volume 75
			spawn sleep 15
			return 0
		fi
	fi

	[ ! -s ./SUSPEND-FINISHED ] ||
		mv -f ./SUSPEND-FINISHED ./SUSPEND-FAILED
	return 0
}

express_resume_player()
{
	# Autoplay in a chromium-based browser whith the YouTube player
	if [ -z "$local_video_sample" ] && [ "$class" = chromium ]; then
		spawn xdotool search --sync --onlyvisible --class "$class" \
			windowactivate key XF86AudioPlay sleep 0.3 keyup XF86AudioPlay
	fi

	msg="${L267-Click the «Play» button if the video does not play}"
	spawn notify-send "$(nls_title)" "$msg"
}

express_additional_hw()
{
	local msg t=20
	local active_ethernet=
	local active_wireless=

	# Checking the secondary network connection
	if has_binary nmcli && express_has_dualnet; then
		msg="${L265-Checking wireless network connection}..."
		spawn notify-send "$(nls_title)" "$msg"
		spawn nmcli c down "$active_ethernet" ||:
		spawn nmcli c up "$active_wireless" ||:
		spawn sleep "$t"

		if check_internet; then
			express_save_date WIFI-PASSED
		else
			express_save_date WIFI-FAILED
		fi

		msg="${L255-Switching back to the wired connection...}"
		spawn notify-send "$(nls_title)" "$msg"
		spawn nmcli c up "$active_ethernet" ||:
		spawn sleep 10
	fi

	# Checking the Internet connection
	check_internet || express_save_date NETWORK-FAILED

	# Double the time
	t="$(( $t + $t ))"

	# Last chance for manual testing
	msg="Now you can continue testing in manual mode, using the mouse,"
	msg="$msg function keys, moving the video window to other monitors,"
	msg="$msg switch audio to other output devices. There are %s seconds"
	msg="$msg left until the test completes..."
	spawn : Additional time to check remaining equipment
	spawn notify-send "$(nls_title)" "$(printf "${L256-$msg}" "$t")"
	spawn sleep "$t"

	# Closing the browser window and main process
	( spawn kill -TERM "$brpid" ||
		spawn kill -KILL "$brpid" ||:
	  spawn wait "$brpid" ||:
	) 2>/dev/null
}

express_has_dualnet()
{
	local tmpf eth=0 wifi=0
	local type is_active uuid

	type="nmcli -c no -f TYPE,ACTIVE,UUID c"
	tmpf="$(spawn mktemp -qt -- "$progname-XXXXXXXX.tmp")"
	spawn env LANG=C LC_ALL=C $type |tee -- "$tmpf"
	cat -- "$tmpf" >>"$logfile"

	while read -r type is_active uuid; do
		[ "$is_active" = yes ] ||
			continue
		if [ "$type" = wifi ]; then
			wifi=$((1 + $wifi))
			active_wireless="$uuid"
		elif [ "$type" = ethernet ]; then
			active_ethernet="$uuid"
			eth=$((1 + $eth))
		fi
	done <"$tmpf"

	spawn rm -f -- "$tmpf"
	[ "$wifi" != 1 ] || [ "$eth" != 1 ] ||
		return 0
	active_ethernet=
	active_wireless=

	return 1
}

express_save_date()
{
	env LANG=C LC_ALL=C date >./"$1"
}

express_pause()
{
	local s0 s1=0 pause=10

	s0="$(date +%s)"

	while [ "$(( $s1 - $s0 ))" -lt "$pause" ]; do
		false || sleep .4
		s1="$(date +%s)"
	done
}

express_try_reboot()
{
	local msg

	if [ -s ./REBOOT-STARTED ]; then
		express_save_date REBOOT-FINISHED
		return 0
	fi

	msg="${L266-Checking the possibility of rebooting}..."
	spawn notify-send "$(nls_title)" "$msg"
	spawn sleep 5
	msg="${L054-Rebooting the system...}"
	printf "[${CLR_BOLD}%s${CLR_NORM}] ${CLR_ERR}%s${CLR_NORM}\n" \
		"$(date '+%T')" "$msg" |tee -a -- "$logfile" >&2
	express_save_date REBOOT-STARTED
	spawn exec systemctl -i reboot ||
		express_save_date REBOOT-FAILED
	return 0
}

express_show_results()
{
	local rc name

	# Results details for non-blocked autotest only
	[ "$1" != "$TEST_BLOCKED" ] && [ -s ./EXPRESS-AUTOTEST ] ||
		return 0
	rc="$(head -n1 ./EXPRESS-AUTOTEST)"
	[ "$rc" = 0 ] ||
		return 0

	# Shutdown test results
	if [ ! -s ./POWEROFF-STARTED ]; then
		rc="$TEST_SKIPPED"
	elif [ ! -s ./POWEROFF-FINISHED ]; then
		rc="$TEST_FAILED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L259-Checking shutdown (Power OFF)}"
	draw_title_line "$rc" "$number.1" "$name"

	# Show/change settings test results
	if [ ! -s ./REBOOT-STARTED ]; then
		rc="$TEST_BLOCKED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L263-Showing and changing settings}"
	draw_title_line "$rc" "$number.2" "$name"

	# Hibernation test results
	if [ ! -s ./HIBERNATE-STARTED ]; then
		rc="$TEST_SKIPPED"
	elif [ ! -s ./HIBERNATE-FINISHED ]; then
		rc="$TEST_FAILED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L257-Checking ACPI/S4 (Hibernation)}"
	draw_title_line "$rc" "$number.3" "$name"

	# Suspend to RAM test results
	if [ ! -s ./SUSPEND-STARTED ]; then
		rc="$TEST_SKIPPED"
	elif [ ! -s ./SUSPEND-FINISHED ]; then
		rc="$TEST_FAILED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L258-Checking ACPI/S3 (Suspend to RAM)}"
	draw_title_line "$rc" "$number.4" "$name"

	# Wired network test results
	if [ -s ./NETWORK-FAILED ]; then
		rc="$TEST_FAILED"
	elif [ ! -s ./POWEROFF-STARTED ]; then
		rc="$TEST_SKIPPED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L264-Checking network connection and interfaces}"
	draw_title_line "$rc" "$number.5" "$name"

	# Wireless network test results
	if [ -s ./WIFI-FAILED ]; then
		rc="$TEST_FAILED"
	elif [ -s ./WIFI-PASSED ]; then
		rc="$TEST_PASSED"
	else
		rc="$TEST_SKIPPED"
	fi
	name="${L265-Checking wireless network connection}"
	draw_title_line "$rc" "$number.6" "$name"

	# Reboot test results
	if [ -s ./REBOOT-FAILED ]; then
		rc="$TEST_FAILED"
	elif [ ! -s ./REBOOT-STARTED ]; then
		rc="$TEST_SKIPPED"
	else
		rc="$TEST_PASSED"
	fi
	name="${L266-Checking the possibility of rebooting}"
	draw_title_line "$rc" "$number.7" "$name"
}

