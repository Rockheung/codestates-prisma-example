#!/bin/sh

if [ ! -f "employees_db-full.tar.bz2" ]; then
  curl https://launchpadlibrarian.net/24493586/employees_db-full-1.0.6.tar.bz2 --output employees_db-full.tar.bz2
fi

if [ -f "employees_db/employees.sql_" ]; then
  rm -rf employees_db
fi

tar -xvjf employees_db-full.tar.bz2

sed -i_ "s/storage_engine/default_storage_engine/g; s/load_/employees_db\/load_/g; /^\ *FOREIGN/d; /^\ *KEY/d; s/employees;/samples;/g" employees_db/employees.sql

cp .env.example .env