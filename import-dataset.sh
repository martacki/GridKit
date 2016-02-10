#!/bin/bash
if [ -z "$1" ] || [ ! -f "$1" ]
then
    echo Please pass OSM datafile as argument
    exit 1
fi
OSM_DATAFILE=$1

if [ -z "$PGDATABASE" ]
then
    if [ -z "$2" ]
    then
        echo Please pass database name as second argument
        exit 1
    else
        export PGDATABASE=$2
    fi
fi

dropdb --if-exists $PGDATABASE || exit 1
createdb $PGDATABASE || exit 1
psql -c 'CREATE EXTENSION postgis;' || exit 1
psql -c 'CREATE EXTENSION hstore;' || exit 1

osm2pgsql -d $PGDATABASE -c -k -s \
	-S ./power.style \
	$OSM_DATAFILE || exit 1

time psql -f ./prepare-tables.sql

