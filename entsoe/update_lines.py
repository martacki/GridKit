import pandas as pd
import numpy as np

# copied from pypsa to avoid installation of pypsa in docker (too slow)
def haversine_pts(a, b):
    """
    Determines crow-flies distance between points in a and b

    ie. distance[i] = crow-fly-distance between a[i] and b[i]

    Parameters
    ----------
    a, b : N x 2 - array of dtype float
        Geographical coordinates in longitude, latitude ordering

    Returns
    -------
    c : N - array of dtype float
        Distance in m

    See also
    --------
    haversine : Matrix of distances between all pairs in a and b
    """

    lon0, lat0 = np.deg2rad(np.asarray(a, dtype=float)).T
    lon1, lat1 = np.deg2rad(np.asarray(b, dtype=float)).T

    c = (np.sin((lat1-lat0)/2.)**2 + np.cos(lat0) * np.cos(lat1) *
         np.sin((lon0 - lon1)/2.)**2)
    return 6371.000 * 2 * np.arctan2( np.sqrt(c), np.sqrt(1-c) ) * 1000

buses = (pd.read_csv('result/buses.csv', quotechar="'", dtype=dict(bus_id='str')).set_index('bus_id'))

lines = (pd.read_csv('result/lines.csv', quotechar="'", true_values=['t'], false_values=['f'],
                     dtype=dict(line_id='str', bus0='str', bus1='str',
                                underground="bool", under_construction="bool")))

lines_3 = (pd.read_csv('database/lines_3.csv', quotechar="'", true_values=['t'], false_values=['f'],
                       dtype=dict(line_id='str', bus0='str', bus1='str',
                                  underground="bool", under_construction="bool")))

lines_4 = (pd.read_csv('database/lines_4.csv', quotechar="'", true_values=['t'], false_values=['f'],
                       dtype=dict(line_id='str', bus0='str', bus1='str',
                                  underground="bool", under_construction="bool")))

lines_5 = (pd.read_csv('database/lines_5.csv', quotechar="'", true_values=['t'], false_values=['f'],
                       dtype=dict(line_id='str', bus0='str', bus1='str',
                                  underground="bool", under_construction="bool")))

#adapt line lengths of corrupted lines
lines.at[lines_3.index, "length"] = haversine_pts(buses.loc[lines.loc[lines_3.index].bus0][['x','y']],
                                                  buses.loc[lines.loc[lines_3.index].bus1][['x','y']])
lines.at[lines_4.index, "length"] = haversine_pts(buses.loc[lines.loc[lines_4.index].bus0][['x','y']],
                                                  buses.loc[lines.loc[lines_4.index].bus1][['x','y']])
lines.at[lines_5.index, "length"] = haversine_pts(buses.loc[lines.loc[lines_5.index].bus0][['x','y']],
                                                  buses.loc[lines.loc[lines_5.index].bus1][['x','y']])

lines_3.length = haversine_pts(buses.loc[lines_3.bus0][['x','y']],
                               buses.loc[lines_3.bus1][['x','y']])

lines_4.length = haversine_pts(buses.loc[lines_4.bus0][['x','y']],
                               buses.loc[lines_4.bus1][['x','y']])

#adapt line indices of lines_3, _4 and _5
lines_3.line_id = lines_3.line_id + '_2'
lines_4.line_id = lines_4.line_id + '_3'
lines_5.line_id = lines_4.line_id + '_4'

#save output
(lines
 .append(lines_3)
 .append(lines_4)
 .append(lines_5)
 .to_csv('result/lines.csv', quotechar="'", index=False))
