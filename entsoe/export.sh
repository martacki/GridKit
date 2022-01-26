#!/bin/bash

psql -c "COPY topology_edges_helper to STDOUT WITH CSV HEADER QUOTE ''''" > database/topology_edges_helper.csv
psql -c "COPY raw_linedata_1 to STDOUT WITH CSV HEADER QUOTE ''''" > database/raw_linedata_1.csv #propagate backwards with index 1
psql -c "COPY raw_linedata to STDOUT WITH CSV HEADER QUOTE ''''" > database/raw_linedata.csv
psql -c "COPY topology_edges to STDOUT WITH CSV HEADER QUOTE ''''" > database/topology_edges.csv
psql -c "COPY line_structure to STDOUT WITH CSV HEADER QUOTE ''''" > database/line_structure.csv
psql -c "COPY station_terminal to STDOUT WITH CSV HEADER QUOTE ''''" > database/station_terminal.csv

psql -c "COPY network_bus TO STDOUT WITH CSV HEADER QUOTE ''''" > result/buses.csv
psql -c "COPY network_line TO STDOUT WITH CSV HEADER QUOTE ''''" > result/lines.csv
psql -c "COPY network_link TO STDOUT WITH CSV HEADER QUOTE ''''" > result/links.csv
psql -c "COPY network_converter TO STDOUT WITH CSV HEADER QUOTE ''''" > result/converters.csv
psql -c "COPY network_transformer TO STDOUT WITH CSV HEADER QUOTE ''''" > result/transformers.csv
psql -c "COPY network_generator TO STDOUT WITH CSV HEADER QUOTE ''''" > result/generators.csv
