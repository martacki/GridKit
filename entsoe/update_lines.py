import pandas as pd

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

lines_3.line_id = lines_3.line_id + '_2'
lines_4.line_id = lines_4.line_id + '_3'
lines_5.line_id = lines_4.line_id + '_4'

(lines
 .append(lines_3)
 .append(lines_4)
 .append(lines_5)
 .to_csv('result/lines.csv', quotechar="'", index=False))
