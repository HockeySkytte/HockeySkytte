# Select the Schema/Database you created earlier
use public;

# Truncate tables before loading CSV data into them
truncate NHL_pbp;
truncate NHL_shifts;
truncate NHL_Bios;
truncate NHL_gameresults;

# Load data from CSV files into MySQL tables
load data infile
'C:/Public/NHL/pbp.csv'
into table NHL_pbp
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/Shift.csv'
into table NHL_shifts
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/players.csv'
into table NHL_bios
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/schedule.csv'
into table NHL_gameresults
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

# Define Strength States from the SituationCode - 1st digit is Away Goalie, 2nd digit is count of Away Skaters, 3rd digit is count of Home Skaters and 4th digit is Home Goalie
create table StrengthStatesPBP select distinct situationCode,
	case when length(situationCode)=4 and right(situationCode,1)='1' then concat( substring(situationCode,2,1), 'v', substring(situationCode,3,1))
    when situationcode='101' then '1v0' when situationcode='1010' then '0v1'
    when length(situationCode)=3 then 'ENF' when right(situationCode,1)='0' then 'ENA'
    else null END as StrengthState_Away,
    case when length(situationCode)=4 and right(situationCode,1)='1' then concat( substring(situationCode,3,1), 'v', substring(situationCode,2,1)) 
    when situationcode='1010' then '1v0' when situationcode='101' then '0v1'
    when length(situationCode)=3 then 'ENA' when right(situationCode,1)='0' then 'ENF'
    else null END as StrengthState_Home
FROM NHL_pbp;

# 1) Calculate gameTime from the period and timeInPeriod
# 2) Combine all the PlayerId columns to just three columns:
#		Player1: Scorer, Shooter, Hitter, Faceoff Winner, Penalty taker and takeaway/giveaway player 
#		Player2: Shot blocker (can be a teammate!), Hitted player, Primary assist player and Penalty drawer 
#		Player3: Secondary assist player and Player serving the penalty
# 3) Calculate the Venue of the EventTeam
# 4) Add StrengthState_Away and StrengthState_Home from the StrengthStatesPBP table. 
# 5) Calculate Corsi, Fenwick, Shot and Goal Columns.
create table pbp_temp1 select pbp.GameID, period, left(timeInPeriod,2)*60+right(timeInPeriod,2)+period*1200-1200 as gameTime, pbp.situationCode, 
		typeCode, typeDescKey, sortOrder, xCoord, yCoord, zoneCode, reason, shotType, awaySOG, homeSOG, pbp.awayScore, pbp.homeScore, secondaryReason, 
        `typeCode.1` as typeCode2, duration as PEN_duration, coalesce(Team,'') as EventTeam, goalieInNetId,
        hittingPlayerId+shootingPlayerId+winningPlayerId+scoringPlayerId+committedByPlayerId+playerId as Player1_ID,
        hitteePlayerId+blockingPlayerId+assist1PlayerId+drawnByPlayerId as Player2_ID,
        assist2PlayerId+servedByPlayerId as Player3_ID,
        case when eventOwnerTeamId='' then '' when Team=HomeTeam then 'Home' else 'Away' END as Venue,
        StrengthState_Away, StrengthState_Home,
        case when typeDescKey='blocked-shot' or typeDescKey='missed-shot' or typeDescKey='shot-on-goal' or typeDescKey='goal' then 1 else 0 END as Corsi,
        case when typeDescKey='missed-shot' or typeDescKey='shot-on-goal' or typeDescKey='goal' then 1 else 0 END as Fenwick,
        case when typeDescKey='shot-on-goal' or typeDescKey='goal' then 1 else 0 END as Shot,
        case when typeDescKey='goal' then 1 else 0 END as Goal
	from NHL_pbp as pbp
    left join NHL_teams as teams
		on pbp.eventOwnerTeamId=teams.TeamId
	left join NHL_gameresults as sc
		on pbp.GameID=sc.GameID
	left join strengthstatespbp as str
		on pbp.situationCode=str.situationCode
        order by pbp.GameID, gameTime, sortOrder;

drop table StrengthStatesPBP;

# Group by GameID, period and Venue - Sum xCoord of all unblocked shot attempts (Fenwick=1). 
# In the NHL pbp data the side of the rink is determined by the Venue - I want to always have the offensive end to the right (from the perspective of the EventTeam). 
create table pbp_adj select GameID, period, Venue, sum(xCoord) as Adj
	from pbp_temp1
		where (Venue= 'Away' or Venue='Home') and Fenwick=1
    group by GameID, period, Venue;

# 1) Calculate the StrengthState of the EventTeam. 
# 2) Adjust the x and y coordinates based on the EventTeam - defensive end equals negative x and offensive end equals positive x. 
# 3) Change the Zone of blocked-shots. NHL tracks blocks and not shots blocked, so the Zone is from the perspective of the defending player - We don't want that. 
# 4) Add a unique EventIndex based on the GameID and the event count. 
create table pbp_temp2 select pbp2.GameID, pbp2.Venue, pbp2.period, gameTime, 
	case when pbp2.Venue='Home' then strengthState_Home when pbp2.Venue='Away' then strengthState_Away else null END as StrengthState, 
	typeCode, typeDescKey, sortOrder, 
    case when Adj<0 then -1*xCoord else xCoord END as x,
    case when Adj<0 then -1*yCoord else yCoord END as y,
    case when typeDescKey='blocked-shot' and zoneCode='D' then 'O' when typeDescKey='blocked-shot' and zoneCode='O' then 'D' else zoneCode END as Zone,
	reason, shotType, 
    secondaryReason, typeCode2, PEN_duration, EventTeam, goalieInNetId as Goalie_ID, Player1_ID, Player2_ID, Player3_ID, Corsi, Fenwick, Shot, Goal,
    pbp2.GameID*10000 + row_number () over(partition by GameID Order by GameID, gameTime, sortOrder) as EventIndex
	from pbp_temp1 as pbp2
    left join pbp_adj as adj
		on pbp2.GameID=adj.GameID and pbp2.Venue=adj.Venue and pbp2.period=adj.period;

# 1) Calculate the Start and End times in seconds. 
# 2) Remove rows where shiftNumber = 0. The data has some "ghost" rows where startTime and endTime is the same. 
create table shift_temp1 select GameID, playerId, shiftNumber, teamAbbrev as Team, 
	left(startTime,2)*60+right(startTime,2) + period*1200-1200 as Start,
    CASE when length(endTime)=4 then left(endTime,1)*60+right(endTime,2) + period*1200-1200 else left(endTime,2)*60+right(endTime,2) + period*1200-1200 END as End
	from NHL_shifts
    where shiftNumber>0 and startTime<>'20:00';

# Create a list of all unique Start and End Times for each GameID. UNION function combines and only takes the unique entries. 
# This gives us a list of all shifts (minimum one player gets on and/or off the ice). 
create table shift_temp2
select GameID, Start from shift_temp1
UNION
select GameID, End as Start from shift_temp1;

# Use the LEAD function to calculate 'End' as the next row. If there is no next row with the same GameID the value is 0. 
create table shift_temp3 select *, lead(Start,1,0) over(partition by GameID order by GameID, Start) as End
	from shift_temp2
    order by GameID, Start;

# 1) Add a unique ShiftIndex based on the GameID and the shift count. 
# 2) Remove all shifts where End = 0. 
# We now have a list of all unique shifts.  
create table shift_temp4 select *, row_number () over(partition by GameID order by GameID, Start) + GameID*10000 as ShiftIndex 
	from shift_temp3
    where End>0;

# Join shift_temp1 (all player shifts) with shift_temp4 (all the unique shifts). 
# One player shift usually spans multiple ShiftIndexes! For example a goaltender's shifts.     
create table shift_temp5 select s1.GameID, playerId, shiftNumber, Team, ShiftIndex, s2.Start, s2.End 
	from shift_temp1 as s1
    left join shift_temp4 as s2
		on s1.GameID=s2.GameID and s1.Start<=s2.Start and s1.End>=s2.End;

# Remove all data from the NHL_playerData table. 
truncate NHL_playerData;

# 1) Insert data from the NHL_Player table into the NHL_playerData table. 
# 2) Change all forward positions to 'F'. 
Insert into NHL_playerData select BirthDate, draftOverall, draftYear, height, Nationality, playerId, 
	CASE when Position='G' then 'G' when Position='D' then 'D' else 'F' END as Position, 
    shootsCatches, Name as Player, weight
	from NHL_bios;

# 1) Add Position information from the NHL_playerData table. 
# 2) Add 'Goaltenders' and 'Skaters' columns - Needed to find the Strength State. 
# 3) Add Venue column, by joining the NHL_gameresults table. 
create table shift_temp6 select s.GameID, s.PlayerId, shiftNumber, Team, Position, ShiftIndex, Start, End, 
	CASE when Position='G' then 1 else 0 END as Goaltenders,
    CASE when Position='G' then 0 else 1 END as Skaters,
    CASE when left(Team,3)=HomeTeam then 'Home' when left(Team,3)=AwayTeam then 'Away' else '' END as Venue
	from shift_temp5 as s
    left join NHL_playerData as p
		on s.playerId=p.playerId
	left join NHL_gameresults as sc
		on s.GameID=sc.GameID;

# 1) Group by GameID, ShiftIndex, Start, End, Venue. 
# 2) Sum 'Goaltenders' and 'Skaters' to get how many skaters is on the ice for each shift.     
create table shift_temp7 select GameID, ShiftIndex, Start, End, Venue, SUM(Goaltenders) as Goalies, SUM(Skaters) as Skaters
	from shift_temp6
    group by GameID, ShiftIndex, Start, End, Venue;

# Sum goalies and skaters for both the home and away team to get 'Total_Goalies' and 'Total_Skaters'.     
create table shift_temp8 select *, SUM(Goalies) over (partition by ShiftIndex order by ShiftIndex) Total_Goalies,
	SUM(Skaters) over (partition by ShiftIndex order by ShiftIndex) Total_Skaters
	from shift_temp7;

# Calculate the StrengthState. 
# 	if 'Total_Goalies' = 2 then it's 'Skaters' vs. 'Total_Skaters' - 'Skaters' (same as opposing team skaters). 
#	if 'Goalies' = 0 then it's 'ENF' (empty net for - Meaning no goalie in net).
#	if 'Goalies' = 'Total_Goalies' then the opposing team has no goalie in net - ENA (empty net against).     
create table shift_temp9 select GameID, ShiftIndex, Start, End, Venue, 
	CASE when Total_Goalies>=2 then CONCAT(Skaters,'v',Total_Skaters-Skaters) when Goalies=0 then 'ENF' when Goalies=Total_Goalies then 'ENA' END as StrengthState
	from shift_temp8;

# Cleaning the Strength States. In the data there's often too many skaters on the ice, e.g. 5v6 or 5v7. This is because the player gets on the ice before the other player gets off. 
# This is mostly a problem in later years because the tracking has become automated. 
create table shift_temp10 select GameID, ShiftIndex, Start, End, Venue,
	CASE when StrengthState='5v4' or StrengthState='6v4' or StrengthState='7v4' then '5v4' 
		when StrengthState='4v5' or StrengthState='4v6' or StrengthState='4v7' then '4v5' 
        when StrengthState='5v3' or StrengthState='6v3' or StrengthState='7v3' then '5v3' 
		when StrengthState='3v5' or StrengthState='3v6' or StrengthState='3v7' then '3v5'
        when StrengthState='3v3' then '3v3' when StrengthState='4v4' then '4v4' 
        when StrengthState='ENF' then 'ENF' when StrengthState='ENA' then 'ENA' 
        when StrengthState='3v4' then '3v4' when StrengthState='4v3' then '4v3' else '5v5' END as StrengthState
	from shift_temp9;

# Create two columns with Away and Home Strength States instead of one column.     
create table shift_temp11 select GameID, ShiftIndex, Start, End, 
	CASE when Venue='Away' then StrengthState else '' END as Away_StrengthState,
    CASE when Venue='Home' then StrengthState else '' END as Home_StrengthState
	from shift_temp10;

# 1) Group by GameID, ShiftIndex, Start and End to ensure we only have one row for each shift - Instead of one for both Home and Away. 
# 2) Get the 'Away_StrengthState' and 'Home_StrengthState' by taking the max values.  
create table shift_temp12 select GameID, ShiftIndex, Start, End, MAX(Away_StrengthState) as Away_StrengthState, MAX(Home_StrengthState) as Home_StrengthState
	from shift_temp11
    group by GameID, ShiftIndex, Start, End;

# Add a player count based on Venue and Position to our Playershifts table (shift_temp6). This will be used to determine forward lines and defensive pairs. 
Create table shift_temp13 Select PlayerId, Position, Team, ShiftIndex, Venue, 
    row_number () over(partition by ShiftIndex, Venue, Position order by ShiftIndex, PlayerID) as On_Ice_Position
	from shift_temp6;

# Create the ShiftIndex table with PlayerIds for Forward lines, Defensive pairs and goalies. I'm using Group by, MAX, CONCAT and TRIM to remove trailing spaces. 
Create table shift_temp14 select GameID, s1.ShiftIndex, Start, End, Away_StrengthState, Home_StrengthState, 
	TRIM(CONCAT(
		MAX(Case when Venue='Home' and Position='F' and On_ice_Position=1 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='F' and On_ice_Position=2 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='F' and On_ice_Position=3 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='F' and On_ice_Position=4 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='F' and On_ice_Position=5 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='F' and On_ice_Position=6 then PlayerID else '' End))) as Home_Forwards,
	TRIM(CONCAT(
		MAX(Case when Venue='Home' and Position='D' and On_ice_Position=1 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='D' and On_ice_Position=2 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='D' and On_ice_Position=3 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='D' and On_ice_Position=4 then PlayerID else '' End),' ',
        MAX(Case when Venue='Home' and Position='D' and On_ice_Position=5 then PlayerID else '' End))) as Home_Defenders,
	MAX(Case when Venue='Home' and Position='G' and On_ice_Position=1 then PlayerID else '' End) as Home_Goalie,
    TRIM(CONCAT(
		MAX(Case when Venue='Away' and Position='F' and On_ice_Position=1 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='F' and On_ice_Position=2 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='F' and On_ice_Position=3 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='F' and On_ice_Position=4 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='F' and On_ice_Position=5 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='F' and On_ice_Position=6 then PlayerID else '' End))) as Away_Forwards,
	TRIM(CONCAT(
		MAX(Case when Venue='Away' and Position='D' and On_ice_Position=1 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='D' and On_ice_Position=2 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='D' and On_ice_Position=3 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='D' and On_ice_Position=4 then PlayerID else '' End),' ',
        MAX(Case when Venue='Away' and Position='D' and On_ice_Position=5 then PlayerID else '' End))) as Away_Defenders,
	MAX(Case when Venue='Away' and Position='G' and On_ice_Position=1 then PlayerID else '' End) as Away_Goalie
	from shift_temp12 as s1
    left join shift_temp13 as s2
		on s1.ShiftIndex=s2.ShiftIndex
	Group by GameID, s1.ShiftIndex, Start, End, Away_StrengthState, Home_StrengthState;

# Select all the distinct Home forward lines and combine it with all the distinct Away forward lines. This gives us all combinations of forwards.
Create table Forwards_temp1 
select distinct Home_Forwards as Forwards from shift_temp14
UNION
select distinct Away_Forwards as Forwards from shift_temp14;

# Select all the distinct Home defensive pairs and combine it with all the distinct Away defensive pairs. This gives us all combinations of defenders.
Create table Defenders_temp1 
select distinct Home_Defenders as Defenders from shift_temp14
UNION
select distinct Away_Defenders as Defenders from shift_temp14;

# Split the forward lines to new columns with the PlayerIds.
Create table Forwards_temp2 select Forwards, substring_index(Forwards,' ',1) as F1, substring_index(substring_index(Forwards,' ',2),' ',-1) as F2,
	substring_index(substring_index(Forwards,' ',3),' ',-1) as F3, substring_index(substring_index(Forwards,' ',4),' ',-1) as F4,
    substring_index(substring_index(Forwards,' ',5),' ',-1) as F5
	from Forwards_temp1;

# Split the defensive pairs to new columns with the PlayerIds.
Create table Defenders_temp2 select Defenders, substring_index(Defenders,' ',1) as D1, substring_index(substring_index(Defenders,' ',2),' ',-1) as D2,
	substring_index(substring_index(Defenders,' ',3),' ',-1) as D3, substring_index(substring_index(Defenders,' ',4),' ',-1) as D4
	from Defenders_temp1;

# Join the forwards table with the player table to get the Names of the forwards. 
Create table Forwards_temp3 select Forwards,
	CASE when F1 is NULL then '' else P1.Player END as F1,
    CASE when F2=F1 then '' else CONCAT(' - ',P2.Player) END as F2,
    CASE when F3=F2 then '' else CONCAT(' - ',P3.Player) END as F3,
    CASE when F4=F3 then '' else CONCAT(' - ',P4.Player) END as F4,
    CASE when F5=F4 then '' else CONCAT(' - ',P5.Player) END as F5
	from Forwards_temp2 as F
    left join NHL_playerData as P1
		on F.F1=P1.PlayerId
	left join NHL_playerData as P2
		on F.F2=P2.PlayerId
	left join NHL_playerData as P3
		on F.F3=P3.PlayerId
	left join NHL_playerData as P4
		on F.F4=P4.PlayerId
	left join NHL_playerData as P5
		on F.F5=P5.PlayerId;

# Join the defenders table with the player table to get the Names of the defenders. 
Create table Defenders_temp3 select Defenders,
	CASE when D1 is NULL then '' else P1.Player END as D1,
    CASE when D2=D1 then '' else CONCAT(' - ',P2.Player) END as D2,
    CASE when D3=D2 then '' else CONCAT(' - ',P3.Player) END as D3,
    CASE when D4=D3 then '' else CONCAT(' - ',P4.Player) END as D4
	from Defenders_temp2 as D
    left join NHL_playerData as P1
		on D.D1=P1.PlayerId
	left join NHL_playerData as P2
		on D.D2=P2.PlayerId
	left join NHL_playerData as P3
		on D.D3=P3.PlayerId
	left join NHL_playerData as P4
		on D.D4=P4.PlayerId;

# Combine the forward names into forward lines using CONCAT.
Create table NHL_Forward_Lines_temp select Forwards, CONCAT(F1,F2,F3,F4,F5) as Forward_Line from Forwards_temp3;

# Combine the defender names into defensive pairs using CONCAT.
Create table NHL_Defensive_Pairs_temp select Defenders, CONCAT(D1,D2,D3,D4) as Defensive_Pair from Defenders_temp3;

# Create the final ShiftIndex table with Player names. 
Create table shift_temp15 select GameID, ShiftIndex, Start, End, End-Start as Duration, Away_StrengthState, Home_StrengthState,
	Home_Forwards as Home_Forwards_ID, H_F.Forward_Line as Home_Forwards,
    Home_Defenders as Home_Defenders_ID, H_D.Defensive_Pair as Home_Defenders,
    Home_Goalie as Home_Goalie_ID, H_G.Player as Home_Goalie,
    Away_Forwards as Away_Forwards_ID, A_F.Forward_Line as Away_Forwards,
    Away_Defenders as Away_Defenders_ID, A_D.Defensive_Pair as Away_Defenders,
    Away_Goalie as Away_Goalie_ID, A_G.Player as Away_Goalie
	from shift_temp14 as s
    left join NHL_Forward_Lines_temp as H_F
		on s.Home_Forwards=H_F.Forwards
	left join NHL_Forward_Lines_temp as A_F
		on s.Away_Forwards=A_F.Forwards
	left join NHL_Defensive_pairs_temp as H_D
		on s.Home_Defenders=H_D.Defenders
	left join NHL_Defensive_pairs_temp as A_D
		on s.Away_Defenders=A_D.Defenders
	left join NHL_PlayerData as H_G
		on s.Home_Goalie=H_G.PlayerId
	left join NHL_PlayerData as A_G
		on s.Away_Goalie=A_G.PlayerId;

# Insert the ShiftIndex data into NHL_ShiftIndex table. 
insert into NHL_ShiftIndex select * from shift_temp15 where ShiftIndex>0;

# Drop all the unnecessary temp tables
drop table shift_temp1;
drop table shift_temp2;
drop table shift_temp3;
drop table shift_temp4;
drop table shift_temp5;
drop table shift_temp6;
drop table shift_temp7;
drop table shift_temp8;
drop table shift_temp9;
drop table shift_temp10;
drop table shift_temp11;
drop table shift_temp12;
drop table shift_temp13;
drop table shift_temp14;
drop table Forwards_temp1;
drop table Forwards_temp2;
drop table Forwards_temp3;
drop table Defenders_temp1;
drop table Defenders_temp2;
drop table Defenders_temp3;
drop table NHL_Forward_Lines_temp;
drop table NHL_Defensive_Pairs_temp;

# Join the play-by-play table (pbp_temp2) and the ShiftIndex table (NHL_ShiftIndex). 
# If an event happens at the same time as a shift, then we're including the players getting off the ice... Unless it's a faceoff or period-start. 
create table pbp_temp3 select pbp3.GameID, Venue, period, gameTime, coalesce(StrengthState,'') as StrengthState, typeCode, typeDescKey, x, y, Zone, reason, 
	shotType, secondaryReason, typeCode2, PEN_duration, EventTeam, Goalie_ID, G.Player as Goalie, 
    Player1_ID, p1.Player as Player1, Player2_ID, p2.Player as Player2, Player3_ID, p3.Player as Player3, 
    Corsi, Fenwick, Shot, Goal, EventIndex, ShiftIndex,
    (SUM(Goal) over(partition by pbp3.GameID, Venue order by pbp3.GameID, EventIndex))*2 - 
    SUM(Goal) over(partition by pbp3.GameID order by pbp3.GameID, EventIndex) as ScoreState,
    Home_Forwards_ID, Home_Forwards, Home_Defenders_ID, Home_Defenders, Home_Goalie_ID, Home_Goalie, 
    Away_Forwards_ID, Away_Forwards, Away_Defenders_ID, Away_Defenders, Away_Goalie_ID, Away_Goalie
	from pbp_temp2 as pbp3
    left join shift_temp15 as sh
		on pbp3.GameID=sh.GameID and 
        ((pbp3.gameTime>sh.Start and pbp3.gameTime<=sh.End and pbp3.typeDescKey<>'period-start' and pbp3.typeDescKey<>'faceoff') or
        (pbp3.gameTime>=sh.Start and pbp3.gameTime<sh.End and (pbp3.typeDescKey='period-start' or pbp3.typeDescKey='faceoff')))
	left join NHL_playerData as G
		on pbp3.Goalie_ID=G.PlayerId
	left join NHL_playerData as p1
		on pbp3.Player1_ID=p1.PlayerId
	left join NHL_playerData as p2
		on pbp3.Player2_ID=p2.PlayerId
	left join NHL_playerData as p3
		on pbp3.Player3_ID=p3.PlayerId
    order by pbp3.GameID, EventIndex;

# Create a table with the EventIndex and BoxIDs from the BoxID_Coordinates table. 
# In the NHL the coodinates are only intergers, so the BoxID_Coordinates table simply has BoxIDs based on every possible combination of x and y. 
create table rinkzones_temp select GameID, EventIndex, s.x, s.y, BoxID, BoxID_rev
	from pbp_temp3 as s
	left JOIN boxid_coordinates as r
		on s.x = r.x and s.y = r.y;

# Add the BoxSize from the BoxID_Size table. 
# Because the coordinates are all integers I'm not calculating the area of each box. Instead I'm counting coordinate points within each box. 
# Many of the coordinates are on the border, so it matters quite a bit to which box they belong. 
create table rinkzones_temp2 select GameID, EventIndex, r.BoxID, r.BoxID_rev, Size as BoxSize
	from rinkzones_temp as r
    left join boxid_size as b
		on r.BoxID=b.BoxID;

# 1) Change gameType to SeasonState: 2=regular and 3=playoffs
# 2) Calculate Shotdistance using Pythagoras - Net is in position (89,0)
# 3) Calculate ShotAngle
# 4) Calculate shotType2, ScoreState2 and StrengthState2 - Used for xG modelling
# 5) Add RinkVenue - Season and HomeTeam combined
# 6) Use the LAG function to find the LastEvent, LastEventTeam and TSLE (time since last event)
# 7) Join tables NHL_PlayerData and rinkzones_temp2 to get BoxID data and Position/Shoots information
create table PBPData_temp1 select p.GameID, g.season, 
	CASE when gameType=2 then 'regular' when gameType=3 then 'playoffs' else '' END as SeasonState,
	p.Venue, p.period, p.gameTime, p.StrengthState, p.typeCode, p.typeDescKey as Event, p.x, p.y, p.Zone, p.reason, 
	p.shotType, p.secondaryReason, p.typeCode2, p.PEN_duration, p.EventTeam, p.Goalie_ID, p.Goalie, p.Player1_ID, p.Player1, p.Player2_ID, p.Player2, p.Player3_ID, p.Player3,
    p.Corsi, p.Fenwick, p.Shot, p.Goal, p.EventIndex, p.ShiftIndex, p.ScoreState, 
    Home_Forwards_ID, Home_Forwards, Home_Defenders_ID, Home_Defenders, Home_Goalie_ID, Home_Goalie, 
    Away_Forwards_ID, Away_Forwards, Away_Defenders_ID, Away_Defenders, Away_Goalie_ID, Away_Goalie,
    r.BoxID, r.BoxID_rev, r.BoxSize, 
    CASE when Fenwick=1 then power(power(89-x,2)+power(y,2),0.5) else '' END as ShotDistance,
    CASE when Fenwick=1 then atan2(0-y,89-x)*57.2957795 else '' END as ShotAngle,
    CASE when shotType='wrist' or shotType='tip-in' or shotType='snap' or shotType='slap' or shotType='backhand' or shotType='deflected' or shotType='wrap-around' or shotType='' 
		then shotType else 'other' END as shotType2,
	CASE when Scorestate<-2 then -3 when ScoreState>2 then 3 else ScoreState END as ScoreState2, 
    CONCAT(g.season,'-',g.HomeTeam) as RinkVenue,
    CASE when StrengthState='5v4' or StrengthState='ENF' then 'PP1' when StrengthState='5v3' or StrengthState='4v3' then 'PP2'
		when StrengthState='4v5' or StrengthState='3v5' or StrengthState='3v4' then 'SH' else StrengthState END as StrengthState2,
	CASE when Fenwick=1 then LAG(typeDescKey) OVER(partition by p.GameID order by EventIndex) else '' END as LastEvent,
    CASE when Fenwick=1 then LAG(EventTeam) OVER(partition by p.GameID order by EventIndex) else '' END as LastEventTeam,
    CASE when Fenwick=1 then gameTime - LAG(gameTime) OVER(partition by p.GameID order by EventIndex) else '' END as TSLE, #Time since last event 
    Coalesce(pl.Position,'') as Position, Coalesce(pl.shootsCatches,'') as Shoots
	from pbp_temp3 as p
    left join rinkzones_temp2 as r
		on p.GameID=r.GameID and p.EventIndex=r.EventIndex
	left join NHL_Gameresults as g
		on p.GameID=g.GameID
	left join NHL_PlayerData as pl
		on p.Player1=pl.playerId
    order by p.GameID, p.EventIndex;

# Insert into the PBPData_before_xG table
# 1) If a shot happens within 3 seconds of a shot, takeaway or giveaway then it's defined as a rebound.
# 2) If a shot happens withon 3 seconds of any other event, then it's defined as a quick event.
# 3) LastEventTeam is defined as either the shooting team or the opponent team
Insert into PBPData_before_xG select GameID, Season, SeasonState, Venue, Period, gameTime, StrengthState, typeCode, Event, x, y, Zone, reason, shotType, 
	secondaryReason, typeCode2, PEN_duration, EventTeam, Goalie_ID, Goalie, Player1_ID, Player1, Player2_ID, Player2, Player3_ID, Player3, 
    Corsi, Fenwick, Shot, Goal, EventIndex, ShiftIndex, ScoreState, 
    Home_Forwards_ID, Home_Forwards, Home_Defenders_ID, Home_Defenders, Home_Goalie_ID, Home_Goalie, 
    Away_Forwards_ID, Away_Forwards, Away_Defenders_ID, Away_Defenders, Away_Goalie_ID, Away_Goalie, 
    BoxID, BoxID_rev, BoxSize, ShotDistance, ShotAngle, shotType2,
    ScoreState2, RinkVenue, StrengthState2,
    CASE when Fenwick=1 and TSLE<4 and (LastEvent='blocked-shot' or LastEvent='shot-on-goal' or LastEvent='takeaway' or LastEvent='giveaway') then 'Rebound'
		when Fenwick=1 and TSLE<4 then 'Quick' when Fenwick=1 then 'None' else '' END as LastEvent, #If a shot happens within 3 seconds I'm differentiating between "shots" and other LastEvents. 
	CASE when Fenwick=1 and EventTeam=LastEventTeam then 'Team' when Fenwick=1 then 'Opp' else '' END as LastEventTeam,
	Position, Shoots
	from PBPData_temp1;

# The data from NHL_Gameresults is inserted into the NHL_Schedule table
Insert into NHL_Schedule select GameID, Season, 
	CASE when gameType=2 then 'regular' when gameType=3 then 'playoffs' else '' END as SeasonState, 
    gameDate as Date, startTimeUTC as StartTime, gameState, AwayTeam, AwayScore, HomeTeam, HomeScore, lastPeriodType
	from nhl_gameresults;

# The data from NHL_Bios is inserted into the NHL_PlayerData_All table
Insert into NHL_playerData_All select BirthDate, draftOverall, draftYear, height, Nationality, playerId, 
	CASE when Position='G' then 'G' when Position='D' then 'D' else 'F' END as Position, 
    shootsCatches, Name as Player, weight
	from NHL_Bios;

# All remaining temp tables are dropped
drop table pbp_adj;
drop table pbp_temp1;
drop table pbp_temp2;
drop table pbp_temp3;
drop table rinkzones_temp;
drop table rinkzones_temp2;
drop table pbpdata_temp1;
drop table shift_temp15;