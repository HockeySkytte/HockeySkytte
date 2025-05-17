# Remove all duplicate rows from the NHL_PlayerData_All table - Players appear from every season they played in the league.
# The UNION function only returns unique rows. The first select query is empty (1 is never equal to 0)
# You could also remove duplicates by using GROUP BY. 
Create table NHL_Players select PlayerID, Player, Position, ShootsCatches, LEFT(BirthDate,10) as Birthday, Nationality, Height, Weight, draftOverall as DraftPosition, DraftYear
	from NHL_PlayerData_All where 1=0
UNION
select PlayerID, Player, Position, ShootsCatches, LEFT(BirthDate,10) as Birthday, Nationality, Height, Weight, draftOverall as DraftPosition, DraftYear 
	from NHL_PlayerData_All;

# There are still a few duplicate players. Mostly because they are listed with different weights. 
# I decided to go with the highest weight. Thus removing lightest entry. 
# PlayerID=8448095 is interesting though. Lester Patrick was a defender in early 20th century, but he only has one NHL game as goalie. 
# He was the GM and coach of the New York Rangers in 1927, and he put himself in net in a playoff game when the starter got injured. 
Delete from NHL_Players
    WHERE (PlayerID=8482133 and Weight=175) or (PlayerID=8482765 and Weight=173) or (PlayerID=8481751 and Weight=171) or (PlayerID=8448095 and Position='D');

# Create the table xG_Values. 
CREATE TABLE `xg_values` (
  `Column` text,
  `Feature` text,
  `xG_F` text,
  `xG_S` text,
  `xG_F_EN` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

# Load the coefficients from the xG models build in Python. 
load data infile
'C:/Public/NHL/Data/xG_Values.csv'
into table xg_values
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

# Create the EventData table by joining the xG_Values table multiple times. 
# We are only calculating xG_F and xG_S for shots after the 2009/2010 season. 
# All empty net shots in the xG_S model has the value of 1. 
Create table NHL_EventData select GameID, Season, SeasonState, Venue, Period, gameTime, StrengthState, typeCode, Event, x, y, Zone, reason, 
	shotType, secondaryReason, typeCode2, PEN_duration, EventTeam, Goalie_ID, Goalie, Player1_ID, Player1, Player2_ID, Player2, Player3_ID, Player3, 
    Corsi, Fenwick, Shot, Goal, EventIndex, ShiftIndex, ScoreState, 
    Home_Forwards_ID, Home_Forwards, Home_Defenders_ID, Home_Defenders, Home_Goalie_ID, Home_Goalie, 
    Away_Forwards_ID, Away_Forwards, Away_Defenders_ID, Away_Defenders, Away_Goalie_ID, Away_Goalie, 
    BoxID, BoxID_rev, BoxSize, 
    CASE when x='' then '' else ShotDistance END as ShotDistance, 
    CASE when x='' then '' else ShotAngle END as ShotAngle,
    Position, Shoots, 
    CASE when Fenwick=1 and StrengthState2<>'ENA' and p.Season>20090000 then 1/(1+exp(-Season.xG_F-StrengthState.xG_F-ShotType.xG_F-RinkVenue.xG_F-LastEvent.xG_F-ShotDistance.xG_F*p.ShotDistance-ShotAngle.xG_F*abs(p.ShotAngle)))
		when Fenwick=1 and StrengthState2='ENA' and p.Season>20090000 then 1/(1+exp(-ShotDistance.xG_F*p.ShotDistance-ShotAngle.xG_F*abs(p.ShotAngle)-Intercept.xG_F)) else '' END as xG_F,
	CASE when Shot=1 and StrengthState2<>'ENA' and p.Season>20090000 then 1/(1+exp(-Season.xG_S-StrengthState.xG_S-ShotType.xG_S-RinkVenue.xG_S-LastEvent.xG_S-ShotDistance.xG_S*p.ShotDistance-ShotAngle.xG_S*abs(p.ShotAngle)))
		when Shot=1 and StrengthState2='ENA' and p.Season>20090000 then 1 else '' END as xG_S
	from pbpdata_before_xg as p
    left join xg_values as Season
		on p.Fenwick=1 and p.Season=Season.Feature and Season.Column='Season'
	left join xg_values as StrengthState
		on p.Fenwick=1 and p.StrengthState2=StrengthState.Feature and StrengthState.Column='StrengthState2'
	left join xg_values as ShotType
		on p.Fenwick=1 and p.shotType2=ShotType.Feature and ShotType.Column='shotType2'
	left join xg_values as RinkVenue
		on p.Fenwick=1 and p.RinkVenue=RinkVenue.Feature and RinkVenue.Column='RinkVenue'
	left join xg_values as LastEvent
		on p.Fenwick=1 and p.LastEvent=LastEvent.Feature and LastEvent.Column='LastEvent'
	left join xg_values as ShotDistance
		on p.Fenwick=1 and ShotDistance.Column='ShotDistance'
	left join xg_values as ShotAngle
		on p.Fenwick=1 and ShotAngle.Column='ShotAngle'
	left join xg_values as Intercept
		on p.Fenwick=1 and Intercept.Column='Intercept';

# Write all the finished tables to CSV files in the folder: C:/Public/NHL/Data/
select 'GameID', 'Season', 'SeasonState', 'Venue', 'Period', 'GameTime', 'StrengthState', 'TypeCode', 'Event', 'x', 'y', 'Zone',
	'Reason', 'ShotType', 'SecondaryReason', 'TypeCode2', 'PEN_Duration', 'EventTeam', 'Goalie_ID', 'Goalie', 'Player1_ID', 'Player1',
    'Player2_ID', 'Player2', 'Player3_ID', 'Player3', 'Corsi', 'Fenwick', 'Shot', 'Goal', 'EventIndex', 'ShiftIndex', 'ScoreState', 
    'Home_Forwards_ID', 'Home_Forwards', 'Home_Defenders_ID', 'Home_Defenders', 'Home_Goalie_ID', 'Home_Goalie', 
    'Away_Forwards_ID', 'Away_Forwards', 'Away_Defenders_ID', 'Away_Defenders', 'Away_Goalie_ID', 'Away_Goalie', 
    'BoxID', 'BoxID_rev', 'BoxSize', 'ShotDistance', 'ShotAngle', 'Position', 'Shoots', 'xG_F', 'xG_S'
UNION
select * from NHL_EventData into OUTFILE 'C:/Public/NHL/Data/NHL_EventData.csv' fields terminated by ',';

select 'PlayerID', 'Player', 'Position', 'ShootsCatches', 'Birthday', 'Nationality', 'Height', 'Weight', 'DraftPosition', 'DraftYear' 
UNION
select * from NHL_Players into OUTFILE 'C:/Public/NHL/Data/NHL_Players.csv' fields terminated by ',';

select 'GameID', 'Season', 'SeasonState', 'Date', 'StartTime', 'GameState', 'AwayTeam', 'AwayScore', 'HomeTeam', 'HomeScore', 'LastPeriodType'
UNION
select * from NHL_Schedule into OUTFILE 'C:/Public/NHL/Data/NHL_Schedule.csv' fields terminated by ',';

select 'Team', 'TeamID', 'Name', 'Logo', 'Color'
UNION
select * from NHL_Teams into OUTFILE 'C:/Public/NHL/Data/NHL_Teams.csv' fields terminated by ',';

select 'GameID', 'ShiftIndex', 'Start', 'End', 'Duration', 'Away_StrengthState', 'Home_StrengthState', 
	'Home_Forwards_ID', 'Home_Forwards', 'Home_Defenders_ID', 'Home_Defenders', 'Home_Goalie_ID', 'Home_Goalie', 
    'Away_Forwards_ID', 'Away_Forwards', 'Away_Defenders_ID', 'Away_Defenders', 'Away_Goalie_ID', 'Away_Goalie' 
UNION
select * from NHL_ShiftIndex into OUTFILE 'C:/Public/NHL/Data/NHL_Shifts.csv' fields terminated by ',';