#!/bin/bash

BACKUP_SCRIPT=/usr/local/bin/backup.sh
CRON_JOB="*/3 * * * * /usr/local/bin/backup.sh"

cat > $BACKUP_SCRIPT <<'EOF'
#!/bin/bash

SRC=/etc
DEST=/var/backups
DATE=$(date +%F_%H-%M)

mkdir -p $DEST
tar -czf $DEST/etc_backup_$DATE.tar.gz $SRC
EOF

chmod +x $BACKUP_SCRIPT

crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
