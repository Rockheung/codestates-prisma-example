#!/bin/sh

if [ ! -f "employees_db-full.tar.bz2" ]; then
  curl https://launchpadlibrarian.net/24493586/employees_db-full-1.0.6.tar.bz2 --output employees_db-full.tar.bz2
fi

if [ -f "employees_db/employees.sql_" ]; then
  rm -rf employees_db
  tar -xvjf employees_db-full.tar.bz2
fi

# FK가 잘 걸려있는 경우
sed -i_ "s/storage_engine/default_storage_engine/g; s/load_/employees_db\/load_/g; /^\ *FOREIGN/d; /^\ *KEY/d; s/employees;/$SRC_DB_NAME;/g" employees_db/employees.sql

# FK 없이 애플리케이션 수준에서 관계가 걸려있는 경우
# sed -i_ "s/storage_engine/default_storage_engine/g; s/load_/employees_db\/load_/g; s/employees;/$SRC_DB_NAME;/g" employees_db/employees.sql

cp .env.example .env