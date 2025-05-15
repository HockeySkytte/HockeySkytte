# Load data into our constant tables - These tables don't change.
load data infile
'C:/Public/NHL/Data/BoxID_Size.csv'
into table boxid_size
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/Data/BoxID_Coordinates.csv'
into table boxid_coordinates
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/Data/NHL_Teams.csv'
into table nhl_teams
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;