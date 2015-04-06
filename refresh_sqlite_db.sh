#!/bin/bash
# Refresh sqlite db with the latest spreadsheet I manually prepared.
# Jack Hsu, 02/13/2015

load_data()
{
grep -v ^city_name $csv > $tmp

cat <<EOD |sqlite3 ${dbname}.db
DROP TABLE IF EXISTS csv_load;

CREATE TABLE csv_load (
	city_name	TEXT NOT NULL,
	zip_code	TEXT NOT NULL,
	hospital_name	TEXT NOT NULL,
	address		TEXT NULL,
	phone		TEXT NULL,
	photo_file	TEXT NULL,
	latitude	FLOAT NULL,
	longitude	FLOAT NULL
);

.separator ","
.import $tmp csv_load
EOD

#cat <<EOD |sqlite3 ${dbname}.db
#SELECT * FROM csv_load;
#EOD
}

prepare_ddl()
{
cat <<EOD |sqlite3 ${dbname}.db

DROP TABLE IF EXISTS hospital;
DROP TABLE IF EXISTS zip;
DROP TABLE IF EXISTS city;

CREATE TABLE city (
	city_id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	city_name	TEXT NOT NULL,
	UNIQUE (city_name)
);

CREATE TABLE zip (
	zip_id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	city_id		INTEGER NOT NULL,
	zip_code	TEXT NOT NULL,
	UNIQUE (city_id, zip_code),
	FOREIGN KEY (city_id) REFERENCES city (city_id)
);

CREATE TABLE hospital (
	hospital_id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	zip_id		INTEGER NOT NULL,
	hospital_name	TEXT NOT NULL,
	address		TEXT NULL,
	phone		TEXT NULL,
	photo_file	TEXT NULL,
	latitude	FLOAT NULL,
	longitude	FLOAT NULL,
	UNIQUE (zip_id, hospital_name),
	FOREIGN KEY (zip_id) REFERENCES zip (zip_id)
);

EOD
}

populate_data()
{
cat <<EOD |sqlite3 ${dbname}.db
INSERT INTO city (city_name)
SELECT DISTINCT l.city_name
FROM csv_load l
ORDER BY l.city_name;

INSERT INTO zip (city_id, zip_code)
SELECT DISTINCT c.city_id, l.zip_code
FROM csv_load l, city c 
WHERE l.city_name=c.city_name
ORDER BY c.city_id, l.zip_code;

INSERT INTO hospital (zip_id, hospital_name, address, phone, photo_file, latitude, longitude)
SELECT DISTINCT z.zip_id, l.hospital_name, l.address, l.phone, l.photo_file, l.latitude, l.longitude
FROM csv_load l, zip z
WHERE l.zip_code=z.zip_code
ORDER BY z.zip_id, l.hospital_name;

EOD
}

query_db()
{
TABLES="city zip hospital"
for table in $TABLES; do
  echo "######################################"
  echo "#### Query table '${table}' ..."
  echo "######################################"
  cat <<EOD |sqlite3 ${dbname}.db
SELECT * FROM ${table};
EOD
done
}

# main program
if [ $# -lt 1 ]; then
  echo "syntax:		refresh_sqlite_db.sh <db_name>"
  exit 1
fi
dbname=$1

csv=${dbname}.csv
tmp=/tmp/refresh_sqlite_db.tmp
sql=refresh_sqlite_db.sql

load_data

prepare_ddl
populate_data
query_db
