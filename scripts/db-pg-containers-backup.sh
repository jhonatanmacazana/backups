#!/bin/bash

## ----------------------------------------------------- VARIABLES  -----------------------------------------------------
# Directory where the local backups will be stored
BACKUP_DIR=/home/ubuntu/backup

# Max days to keep backups
MAX_DAYS=3

# Backup all postgres containers.
CONTAINERS=$(docker ps --format '{{.Names}}:{{.Image}}' | grep -e "postgres" -e "postgis" | cut -d":" -f1)
# You can specify a single container overriding the CONTAINERS variable
# CONTAINERS="app_db_1"

# S3 hostname
S3_HOSTNAME=${S3_BUCKET}

# S3 bucket
S3_BUCKET=${S3_BUCKET}

# S3 access key
S3_ACCESS_KEY=${S3_ACCESS_KEY}

# S3 secret key
S3_SECRET_KEY=${S3_SECRET_KEY}

## ----------------------------------------------------- RUN -----------------------------------------------------
# Create backup directory if not exists
if [ ! -d $BACKUP_DIR ]; then
  mkdir -p $BACKUP_DIR
fi

# For each container
for i in $CONTAINERS; do
  echo "$i - $(date +"%Y%m%d%H%M%s") - Starting backup"
  POSTGRES_DB=$(docker exec $i env | grep POSTGRES_DB | cut -d"=" -f2)
  POSTGRES_USER=$(docker exec $i env | grep POSTGRES_USER | cut -d"=" -f2)

  BACKUP_FILE_NAME=$i-$POSTGRES_DB-$(date +"%Y%m%d%H%M").sql.gz
  # Create backup
  docker exec -e POSTGRES_DB=$POSTGRES_DB -e POSTGRES_USER=$POSTGRES_USER \
    $i /usr/bin/pg_dump -U $POSTGRES_USER $POSTGRES_DB |
    gzip >$BACKUP_DIR/$BACKUP_FILE_NAME
  # gzip >$BACKUP_DIR/$i-$POSTGRES_DB-$(date +"%Y%m%d%H%M").sql.gz

  # Delete old backups
  OLD_BACKUPS=$(ls -1 $BACKUP_DIR/$i*.gz | wc -l)
  if [ $OLD_BACKUPS -gt $MAX_DAYS ]; then
    find $BACKUP_DIR -name "$i*.gz" -daystart -mtime +$MAX_DAYS -delete
  fi
  echo "$i - $(date +"%Y%m%d%H%M%s") - Backup completed"

  echo "$i - $(date +"%Y%m%d%H%M%s") - Starting S3 upload"
  ./mc alias set backup-s3 $S3_HOSTNAME $S3_ACCESS_KEY $S3_SECRET_KEY
  ./mc cp $BACKUP_DIR/$BACKUP_FILE_NAME backup-s3/$S3_BUCKET/$i/$BACKUP_FILE_NAME
  echo "$i - $(date +"%Y%m%d%H%M%s") - S3 upload completed"

done

echo "$(date +"%Y%m%d%H%M%S") Backup for Databases completed"

## ----------------------------------------------------- CLEANUP  -----------------------------------------------------
unset CONTAINERS MAX_DAYS BACKUP_DIR CONTAINERS
