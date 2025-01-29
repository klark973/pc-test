###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

########################
### Default settings ###
########################

# APT sources lists can be changed by default, reset to disable
update_apt_lists=1

# ALT Linux will be completely updated by default, reset to disable
dist_upgrade=1

# Linux kernel will be updated by default, reset to disable
update_kernel=1

# A URL on the LAN that points to a local FTP, HTTP or RSYNC mirror
local_url=

# The part of /etc/fstab for access to the loacl mirror by network
local_mirror=

# Sub-direcory with repositories inside the local network mirror
mirror_subdir=

# Components of directory on external media with the local mirror
local_media_base=
local_media_labels=( )
local_media_check=

# Console colors
CLR_NORM="\033[00m"
CLR_BOLD="\033[01;37m"
CLR_LC1="\033[00;36m"
CLR_LC2="\033[00;35m"
CLR_OK="\033[01;32m"
CLR_ERR="\033[01;31m"
CLR_WARN="\033[01;33m"

# Unmounted devices are not tested by default because these checks
# are very unsafe. NOTE: insecure testing will be implemented later.
#
unsafe_diskperf=

# When it set, the program will not use the desktop file for autorun
disable_autorun=

# Real IP or name of the Internet server to check the connection
ping_server=ya.ru

# Name of the set of randomly selected videos
express_video_set=youtube

# A URL pointing to a sample Full HD video for Express-testing
local_video_sample=

