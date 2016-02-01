/* assume we use the osm2pgsql 'accidental' tables */
begin transaction;

drop table if exists node_geometry;
drop table if exists way_geometry;
drop table if exists relation_member;
drop table if exists power_type_names;
drop table if exists electrical_properties;
drop table if exists power_station;
drop table if exists power_line;
drop sequence if exists synthetic_objects;
/* functions */
drop function if exists buffered_terminals(geometry(linestring));
drop function if exists buffered_station_point(geometry(point));
drop function if exists buffered_station_area(geometry(polygon));
drop function if exists source_line_objects(text[]);
drop function if exists source_station_objects(text[]);
drop function if exists connect_lines(a geometry(linestring), b geometry(linestring));
drop function if exists connect_lines_terminals(geometry, geometry);
drop function if exists reuse_terminal(geometry, geometry, geometry);
drop function if exists minimal_terminals(geometry, geometry, geometry);



create table node_geometry (
       node_id bigint,
       point   geometry(point, 3857)
);

create table way_geometry (
       way_id bigint,
       line   geometry(linestring, 3857)
);

/* lookup table for power types */
create table power_type_names (
       power_name varchar(64) primary key,
       power_type char(1) not null,
       check (power_type in ('s','l','r', 'v'))
);

create table relation_member (
       relation_id bigint,
       member_id   varchar(64) not null,
       member_role varchar(64) null,
       foreign key (relation_id) references planet_osm_rels (id)
);

create table electrical_properties (
       osm_id varchar(64),
       frequency float array,
       voltage int array,
       conductor_bundles int array,
       subconductors int array,
       power_name varchar(64),
       operator text,
       name text
);

create table power_station (
       osm_id varchar(64),
       power_name varchar(64) not null,
       tags hstore,
       location geometry(point, 3857),
       area geometry(polygon, 3857),
       objects text[],
       primary key (osm_id)
);

create table power_line (
       osm_id varchar(64),
       power_name varchar(64) not null,
       tags hstore,
       extent    geometry(linestring, 3857),
       terminals geometry(geometry, 3857),
       objects   text[],
       primary key (osm_id)
);

-- todo, split function preparation from this file
create function buffered_terminals(line geometry(linestring)) returns geometry(linestring) as $$
begin
    return st_buffer(st_union(st_startpoint(line), st_endpoint(line)), least(50.0, st_length(line)/3.0));
end
$$ language plpgsql;

create function buffered_station_point(point geometry(point)) returns geometry(polygon) as $$
begin
    return st_buffer(point, 50);
end;
$$ language plpgsql;

create function buffered_station_area(area geometry(polygon)) returns geometry(polygon) as $$
begin
    return st_convexhull(st_buffer(area, least(sqrt(st_area(area)), 100)));
end
$$ language plpgsql;


create function source_line_objects (ref text[]) returns text[] as $$
begin
    return array_agg(distinct e) from (select unnest(objects) as e from power_line where osm_id = any(ref)) f;
end
$$ language plpgsql;

create function source_station_objects (ref text[]) returns text[] as $$
begin
    return array_agg(distinct e) from (select unnest(objects) as e from power_station where osm_id = any(ref)) f;
end
$$ language plpgsql;


create function connect_lines (a geometry(linestring), b geometry(linestring)) returns geometry(linestring) as $$
begin
    -- select the shortest line that comes from joining the lines
     -- in all possible directions
    return (select e from (
               select unnest(
                   array[st_makeline(a, b),
                         st_makeline(a, st_reverse(b)),
                         st_makeline(st_reverse(a), b),
                         st_makeline(st_reverse(a), st_reverse(b))]) e) f
                   order by st_length(e) limit 1);
end
$$ language plpgsql;

create function connect_lines_terminals(a geometry(multipolygon), b geometry(multipolygon))
       returns geometry(multipolygon) as $$
begin
    return case when st_intersects(st_geometryn(a, 1), st_geometryn(b, 1)) then st_union(st_geometryn(a, 2), st_geometryn(b, 2))
                when st_intersects(st_geometryn(a, 2), st_geometryn(b, 1)) then st_union(st_geometryn(a, 1), st_geometryn(b, 2))
                when st_intersects(st_geometryn(a, 1), st_geometryn(b, 2)) then st_union(st_geometryn(a, 2), st_geometryn(b, 1))
                                                                           else st_union(st_geometryn(a, 1), st_geometryn(b, 1)) end;
end
$$ language plpgsql;



create function reuse_terminal(point geometry, terminals geometry, line geometry) returns geometry as $$
declare
    max_buffer float;
begin
    max_buffer = least(st_length(line) / 3.0, 50.0);
    if st_geometrytype(terminals) = 'ST_MultiPolygon' then
       if st_distance(st_geometryn(terminals, 1), point) < 1 then
          return st_geometryn(terminals, 1);
       elsif st_distance(st_geometryn(terminals, 2), point) < 1 then
           return st_geometryn(terminals, 2);
      else
           return st_buffer(point, max_buffer);
       end if;
    else
        return st_buffer(point, max_buffer);
    end if;
end;
$$ language plpgsql;

create function minimal_terminals(line geometry, area geometry, terminals geometry) returns geometry as $$
declare
    start_term geometry;
    end_term   geometry;
begin
    start_term = case when st_distance(st_startpoint(line), area) < 1 then st_buffer(st_startpoint(line), 1)
                      else reuse_terminal(st_startpoint(line), terminals, line) end;
    end_term   = case when st_distance(st_endpoint(line), area) < 1 then st_buffer(st_endpoint(line), 1)
                      else reuse_terminal(st_endpoint(line), terminals, line) end;
    return st_union(start_term, end_term);
end;
$$ language plpgsql;





/* all things recognised as certain stations */
insert into power_type_names (power_name, power_type)
       values ('station', 's'),
              ('substation', 's'),
              ('sub_station', 's'),
              ('plant', 's'),
              ('cable', 'l'),
              ('line', 'l'),
              ('minor_cable', 'l'),
              ('minor_line', 'l'),
              -- virtual elements
              ('merge', 'v'),
              ('joint', 'v');


/* we could read this out of the planet_osm_point table, but i'd
 * prefer calculating under my own control */


insert into node_geometry (node_id, point)
       select id, st_setsrid(st_makepoint(lon/100.0, lat/100.0), 3857)
              from planet_osm_nodes;

insert into way_geometry (way_id, line)
       select way_id, ST_MakeLine(n.point order by order_nr)
              from (
                   select id as way_id, unnest(nodes) as node_id, generate_subscripts(nodes, 1) as order_nr
                          from planet_osm_ways
              ) as wn
              join node_geometry n on n.node_id = wn.node_id
              group by way_id;

/* TODO: figure out how to compute relation geometry, given that it
   may be recursive! */
insert into relation_member (relation_id, member_id, member_role)
       select s.pid, s.mid, s.mrole from (
              select id as pid, unnest(akeys(hstore(members))) as mid,
                                unnest(avals(hstore(members))) as mrole
                    from planet_osm_rels
       ) s;


/* stations as ways */
with way_stations as (
        select concat('w', id) as osm_id, hstore(tags) as tags,
                case when st_isclosed(line) then st_makepolygon(line)
                     when st_npoints(line) = 2 then st_buffer(line, 1)
                     else st_makepolygon(st_addpoint(line, st_startpoint(line))) end as geom
                from planet_osm_ways w
                join way_geometry g on g.way_id = w.id
                where hstore(tags)->'power' in (
                        select power_name from power_type_names
                                where power_type = 's'
                )
)
insert into power_station (osm_id, power_name, tags, location, area, objects)
        select osm_id, tags->'power', tags, st_centroid(geom),
               buffered_station_area(geom), array[osm_id]
               from way_stations;

/* stations in the shape of nodes */
with node_stations as (
        select concat('n', id) as osm_id, hstore(tags) as tags, point
                from planet_osm_nodes n
                join node_geometry g on g.node_id = n.id
                where hstore(tags)->'power' in (
                        select power_name from power_type_names where power_type = 's'
                )
)
insert into power_station (osm_id, power_name, tags, location, area, objects)
       select osm_id, tags->'power', tags,  point, buffered_station_point(point), array[osm_id]
              from node_stations;

with way_lines as (
     select concat('w', id) as osm_id, hstore(tags) as tags, line
            from planet_osm_ways w
            join way_geometry g on g.way_id = w.id
            where hstore(tags)->'power' in (
                  select power_name from power_type_names where power_type = 'l'
            )
)
insert into power_line (
       osm_id, power_name, tags, extent, terminals, objects
) select osm_id, tags->'power', tags, line, buffered_terminals(line), array[osm_id]
    from way_lines;

create index power_station_area   on power_station using gist(area);
create index power_line_extent    on power_line    using gist(extent);
create index power_line_terminals on power_line    using gist(terminals);
create index power_line_objects   on power_line    using btree(objects);
create sequence synthetic_objects start 1;

commit;
-- this is an optimization,
vacuum analyze power_line;
vacuum analyze power_station;
