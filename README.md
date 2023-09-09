# borg-backup-script
A script to use borgbackup with crontab


# How to use:
0. Make sure to read the docu https://borgbackup.readthedocs.io/en/stable/
1. Add all needed configs under client config
2. Configure your server, create user, add ssh keys, create backup folder
3. Run borg_backup_script.sh init, wait until its done and backup the printed informations for recovery
4. run borg_backup_script.sh backup to run your first backup. 
5. Add it to crontab, e.g. '0 * * * * sh /borg_backup_script.sh backup' to run it every hour


