#!/bin/sh

if ! [ -x "$(command -v mysqldump)" ]; then
  echo 'Error: mysqldump is not installed.' >&2
  exit 1
fi

DUMP_FILE=dump_$DB_NAME\_$(date +"%Y%m%d").dump

mysqldump \
--column-statistics=0 \
--single-transaction \
--dump-date \
--no-create-info \
--no-create-db \
--complete-insert \
--add-drop-database \
--set-gtid-purged=OFF \
--databases "$SRC_DB_NAME" \
--host=$DB_HOST \
--user=$DB_USER \
--password=$DB_PASS \
--port=$DB_PORT \
> $DUMP_FILE

sed -i_ "s/$SRC_DB_NAME/$DB_NAME@$STAGING/g" $DUMP_FILE

mysql \
--host=127.0.0.1 \
--user=$DB_USER \
--password=$DB_PASS \
--port=$DB_PORT \
< $DUMP_FILE

mkdir -p .tmp
mv $DUMP_FILE $DUMP_FILE\_ .tmp