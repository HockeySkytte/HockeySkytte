# Create tables for xG modelling. We are using the absolute value of ShotAngle - assuming it doesn't matter if the shot comes from left or right. 
Create table Model_Fenwick select EventIndex, Season, ShotDistance, abs(ShotAngle) as ShotAngle, shotType2, ScoreState2, RinkVenue, StrengthState2, LastEvent, LastEventTeam, Position, Shoots, Goal
	from PBPData_before_xG
    where Fenwick=1 and StrengthState2<>'ENA' and x<>'';

Create table Model_Shot select EventIndex, Season, ShotDistance, abs(ShotAngle) as ShotAngle, shotType2, ScoreState2, RinkVenue, StrengthState2, LastEvent, LastEventTeam, Position, Shoots, Goal
	from PBPData_before_xG
    where Shot=1 and StrengthState2<>'ENA' and x<>'';

Create table Model_Fenwick_EN select EventIndex, Season, ShotDistance, abs(ShotAngle) as ShotAngle, shotType2, ScoreState2, RinkVenue, StrengthState2, LastEvent, LastEventTeam, Position, Shoots, Goal
	from PBPData_before_xG
    where Fenwick=1 and StrengthState2='ENA' and x<>'';

# Write the Model tables to CSV files. We need to add the column names. 
select 'EventIndex', 'Season', 'ShotDistance', 'ShotAngle', 'shotType', 'ScoreState', 'RinkVenue', 'StrengthState', 'LastEvent', 'LastEventTeam', 'Position', 'Shoots', 'Goal'
UNION
select * from model_fenwick into OUTFILE 'xG_Model_F.csv' fields terminated by ',';

select 'EventIndex', 'Season', 'ShotDistance', 'ShotAngle', 'shotType', 'ScoreState', 'RinkVenue', 'StrengthState', 'LastEvent', 'LastEventTeam', 'Position', 'Shoots', 'Goal'
UNION
select * from model_fenwick_en into OUTFILE 'xG_Model_F_EN.csv' fields terminated by ',';

select 'EventIndex', 'Season', 'ShotDistance', 'ShotAngle', 'shotType', 'ScoreState', 'RinkVenue', 'StrengthState', 'LastEvent', 'LastEventTeam', 'Position', 'Shoots', 'Goal'
UNION
select * from model_shot into OUTFILE 'xG_Model_S.csv' fields terminated by ',';