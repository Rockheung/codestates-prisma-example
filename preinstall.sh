#!/bin/sh

if [ ! -f "employees_db-full.tar.bz2" ]; then
  curl https://launchpadlibrarian.net/24493586/employees_db-full-1.0.6.tar.bz2 --output employees_db-full.tar.bz2
fi
tar -xvjf employees_db-full.tar.bz2

DUMP_SQL_FILE=employees_db/employees.sql

sed -i_ "s/storage_engine/default_storage_engine/g" $DUMP_SQL_FILE

# rm $DUMP_SQL_FILE\_