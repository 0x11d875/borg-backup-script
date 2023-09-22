#!/bin/bash
#
# borg backup script
# Version: 1.0.0
# Author: 0x11d875
# Description: A script to use borgbackup. After add all neede configs it can be used to create and backup your files with borgbackup
# Date: September 9, 2023
# License: MIT License
# Repository: 
#
# How to use:
# 1. Add all needed configs under client config
# 2. Configure your server, create user, add ssh keys, create backup folder
# 3. Run borg_backup_script.sh init, wait until its done and backup the printed informations for recovery
# 4. run borg_backup_script.sh backup to run your first backup. 
# 5. Add it to crontab, e.g. '0 * * * * sh /borg_backup_script.sh backup' to run it every hour




###############################
# client config
###############################
	USERNAME="" # username on the backup server
	export BORG_PASSPHRASE='' # ADD HERE YOUR LONG PASSWORD

	BORG_DOMAIN="" # ip or domain of the backup server
	BORG_PORT="22"

	BORG_REPO="/home/$USERNAME/backups"

	DEBUG="info" # possbile values: critical, error, warning, info, debug


	# add all path you want to backup
	include_path=(
		'/home'
		'/root'
		'/etc'
		)

	# add paths that you dont want to backup
	exclude_patterns=(
	    '/home/*/cache/*'
	    '/home/*/venv*'
	)
###############################
# client config DONE
###############################


# make sure, password is ok (length check >= 25 chars)
if [ ${#BORG_PASSPHRASE} -ge 24 ]; then
	echo -n ""
else
	echo "Your password length is too short! Please enter a password >= 25 chars."; exit
fi


# concatenate some strings

REPO="ssh://$USERNAME@$BORG_DOMAIN:$BORG_PORT/$BORG_REPO"

TIMESTAMP=`date "+%Y-%m-%d_%H:%M"`
BORG_BACKUP_NAME="$TIMESTAMP"



backup_path=""
# Loop through the array and build the include_path string
for pattern in "${include_path[@]}"; do
    backup_path+="$pattern "
done


exclude_options=""
# Loop through the array and build the exclude_options string
for pattern in "${exclude_patterns[@]}"; do
    exclude_options+="--exclude '$pattern' "
done





init() {
	echo "[$DATE_WITH_TIME] init"
	borg --version
	borg init --$DEBUG --encryption=repokey $REPO
	echo "[$DATE_WITH_TIME] init done. Exit_status: $?"
	borg key export --paper $REPO
	info
}

backup() {
	echo "[$DATE_WITH_TIME] creating backup"
	borg create --$DEBUG -s --progress  --show-rc --verbose --compression lz4 $exclude_options $REPO::$BORG_BACKUP_NAME $backup_path
	echo "[$DATE_WITH_TIME] creating backup done. Exit_status: $?"
	list
	prune
}


prune() {
	echo "[$DATE_WITH_TIME] pruening"
	borg prune -v --list --stats --keep-minutely=60 --keep-hourly=48 --keep-daily=35 --keep-weekly=8 --keep-monthly=24 --keep-yearly=1024 $REPO
	echo "[$DATE_WITH_TIME] prunening done. Exit_status: $?"
}


list() {
	borg list --$DEBUG $REPO
}

info() {
	borg info --$DEBUG $REPO
}

mount() {
	echo "[$DATE_WITH_TIME] mouting backup"
	mkdir -p /tmp/borg_mount
	borg mount --$DEBUG $REPO /tmp/borg_mount
	echo "[$DATE_WITH_TIME] mounting backup done. Exit_status: $?"
}

umount() {
	echo "[$DATE_WITH_TIME] umount backup"
	borg umount --$DEBUG /tmp/borg_mount
	rmdir /tmp/borg_mount
}


diff() {
	echo "[$DATE_WITH_TIME] diff:"
	borg diff $REPO::$1 $2
}


breaklock() {
        echo "[$DATE_WITH_TIME] break-lock:"
        borg break-lock $REPO
}


$1 $2 $3 | tee -a backup.log
