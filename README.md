# How to use:
0. Make sure to read the docu https://borgbackup.readthedocs.io/en/stable/




# Installation

sudo apt install borgbackup fuse3 python3-pyfuse3

vim /etc/borg-backup.conf; chmod 400 /etc/borg-backup.conf
vim /opt/borg-backup.sh; chmod +x /opt/borg-backup.sh



vim /etc/systemd/system/borg-backup.service
vim /etc/systemd/system/borg-backup.timer


systemctl daemon-reload
systemctl enable --now borg-backup.timer

