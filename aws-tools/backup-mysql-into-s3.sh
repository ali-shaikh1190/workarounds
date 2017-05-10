
#!/bin/bash
# Description: Backup multiple mysql schemas into a s3 bucket
# Dependencies: mysql, mysqldump, tar, s3cmd

MYSQL_CMD="mysql --skip-column-names"
MYSQL_DUMP_CMD="mysqldump --single-transaction"
COMPRESS_CMD="tar jcf"
S3CMD_PUT="s3cmd put"
TMP_DIR=/tmp/`basename $0`.$$
DATE="`date +%F-%H_%M`"

function usage
{
  echo "Usage: `basename $0` -b s3_bucket_and_path -u mysql_user -p mysql_password [ -s mysql_schema -s other_mysql_schema ] "
  exit 1
}

function backup_schema
{
  cd $TMP_DIR
  SCHEMA="$1"
  DUMP_FILE="$DATE-$SCHEMA.sql"
  COMPRESSED_FILE="$DUMP_FILE.tar.bz2"
  echo "Backing up $SCHEMA"
  if $MYSQL_DUMP_CMD $SCHEMA > $DUMP_FILE ; then
    $COMPRESS_CMD $COMPRESSED_FILE $DUMP_FILE
    $S3CMD_PUT $COMPRESSED_FILE $S3BUCKET/$SCHEMA/$COMPRESSED_FILE
  else
    echo "Failed to backup $SCHEMA"
  fi
}

while getopts ":u:p:s:b:" opt; do
  case $opt in
    u)
      DBUSER=$OPTARG
      ;;
    p)
      DBPASSWD=$OPTARG
      ;;
    s)
      DBSCHEMAS="$DBSCHEMAS $OPTARG"
      ;;
    b)
      S3BUCKET=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

if [[ -z "$DBUSER" ]] || [[ -z "$DBPASSWD" ]] || [[ -z "$S3BUCKET" ]] ; then
  usage
else
  MYSQL_OPTS="-u $DBUSER -p$DBPASSWD"
  MYSQL_CMD="$MYSQL_CMD $MYSQL_OPTS"
  MYSQL_DUMP_CMD="$MYSQL_DUMP_CMD $MYSQL_OPTS"
  mkdir $TMP_DIR
fi

if [[ -z "$DBSCHEMAS" ]] ; then
  echo "No schemas supplied... all schemas will be backup"
  for DBSCHEMA in `echo "show databases" | $MYSQL_CMD` ; do
    backup_schema $DBSCHEMA
  done
else
  for DBSCHEMA in $DBSCHEMAS ; do
    backup_schema $DBSCHEMA
  done
fi

if [[ -d $TMP_DIR ]] ; then
  rm -rf $TMP_DIR
fi
