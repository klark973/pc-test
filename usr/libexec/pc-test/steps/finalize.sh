###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2024, ALT Linux Team

#############################
### Finalizing of testing ###
#############################

number=10.11
en_name="Final check of kernel messages"
ru_name="Контрольная проверка сообщений ядра"

testcase()
{
	# 10.11. Final check of kernel messages
	spawn dmesg -H -P --color=always |gzip -9 >dmesg_final.gz

	# Version of this program
	spawn "$progname" --version |tee version.txt
}

