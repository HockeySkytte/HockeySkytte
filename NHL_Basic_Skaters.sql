# Select the Schema/Database you created earlier
use public;

# Truncate tables before loading CSV data into them
truncate NHL_skaters;
truncate careerstats;

load data infile
'C:/Public/NHL/Skaters.csv'
into table NHL_skaters
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/careerStats.csv'
into table careerstats
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

Create temporary table Skaters_temp1 select Season, SeasonState, left(Date,10) as Date, s.GameID, Venue, 
	CASE when Venue='Away' then AwayTeam when Venue='Home' then HomeTeam else '' END as Team,
    CASE when Venue='Home' then AwayTeam when Venue='Away' then HomeTeam else '' END as Opponent,
    PlayerId, goals, assists, points, plusMinus, pim, hits, powerPlayGoals as PPG, sog, blockedShots, shifts, giveaways, takeaways,
	CASE when toi<>'' then left(toi,2) + right(toi,2)/60 else null END as TOI
from NHL_Skaters as s
left join NHL_Schedule as g
	on s.GameID=g.GameID;

Create temporary table Skaters_temp2 select Season, SeasonState, Date, GameID, Venue, Team, Opponent, p.PlayerID, Position, Birthday,
	row_number() over(partition by p.PlayerID, SeasonState order by GameID) as Game_No,
	goals, assists, points, plusMinus, pim, hits, PPG, sog, blockedShots, shifts, giveaways, takeaways, TOI
from Skaters_temp1 as s
left join NHL_Players as p
	on s.PlayerId=p.PlayerID
Order by GameID, Venue, p.PlayerID;

Create temporary table Averages_temp1 select Season, Position, COUNT(distinct GameID) as GP, 
	SUM(goals) as goals, SUM(assists) as assists, SUM(Points) as points, SUM(plusMinus) as plusMinus, SUM(pim) as pim,
    SUM(hits) as hits, SUM(PPG) as PPG, SUM(sog) as sog, SUM(blockedShots) as blockedShots, SUM(shifts) as shifts, 
    SUM(giveaways) as giveaways, SUM(takeaways) as takeaways, COALESCE(SUM(TOI),0) as TOI
from Skaters_temp2
Where Position='D' or Position='F'
Group by Season, Position;

Create temporary table Averages_temp2 select Season, Position, goals/GP as goals, assists/GP as assists, points/GP as points, pim/GP as pim, 
	hits/GP as hits, PPG/GP as PPG, sog/GP as sog, blockedShots/GP as blockedShots, shifts/GP as shifts,
    giveaways/GP as giveaways, takeaways/GP as takeaways
from Averages_temp1;

Create temporary table Averages_temp3 select Position, goals/GP as goals, assists/GP as assists, points/GP as points, pim/GP as pim, 
	hits/GP as hits, PPG/GP as PPG, sog/GP as sog, blockedShots/GP as blockedShots, shifts/GP as shifts,
    giveaways/GP as giveaways, takeaways/GP as takeaways
from Averages_temp1
Where Season=20242025;

Create temporary table Averages_temp4 select Season, a1.Position, a2.goals/a1.goals as goals, a2.assists/a1.assists as assists, a2.points/a1.points as points,
	a2.pim/a1.pim as pim, a2.hits/a1.hits as hits, a2.PPG/a1.PPG as PPG, a2.sog/a1.sog as sog,
    a2.blockedShots/a1.blockedShots as blockedShots, a2.shifts/a1.shifts as shifts, 
    a2.giveaways/a1.giveaways as giveaways, a2.takeaways/a1.takeaways as takeaways
from Averages_temp2 as a1
left join Averages_temp3 as a2
	on a1.Position=a2.Position;

Create table NHL_Skater_Era_adjustments select * from Averages_temp4;

Create temporary table Skaters_temp3 select s.Season, s.SeasonState, Date, GameID, Venue, Team, Opponent, PlayerID, s.Position, Birthday, Game_No, 
	'Adjusted' as Era_Adjusted,
    s.goals*a.goals as goals, s.assists*a.assists as assists, s.points*a.points as points, plusMinus, s.pim*a.pim as pim, 
    s.hits*a.hits as hits, s.PPG*a.PPG as PPG, s.sog*a.sog as sog, s.blockedShots*a.blockedShots as blockedShots, 
    s.shifts*a.shifts as shifts, s.giveaways*a.giveaways as giveaways, s.takeaways*a.takeaways as takeaways, TOI
from Skaters_temp2 as s
left join Averages_temp4 as a
	on s.Season=a.Season and s.Position=a.Position;

Create temporary table Skaters_temp4
select Season, SeasonState, Date, GameID, Venue, Team, Opponent, PlayerID, Position, Birthday, Game_No, 'Raw' as Era_adjusted, 
	goals, assists, points, plusMinus, pim, hits, PPG, sog, blockedShots, shifts, giveaways, takeaways, TOI
from Skaters_temp2
UNION ALL
select * from Skaters_temp3;

Create table nhl_skater_games_basic select Season, SeasonState, Date, GameID, Venue, Team, Opponent, PlayerID, Position, Birthday, Game_No, Era_adjusted,
	goals, assists, points,
    CASE when Season>19590000 then plusMinus else null END as plusMinus, pim,
    CASE when Season>19970000 then hits else null END as hits, PPG,
    CASE when Season>19590000 then sog else null END as sog,
    CASE when Season>19970000 then blockedShots else null END as blockedShots,
    CASE when Season>19970000 then shifts else null END as shifts,
    CASE when Season>19970000 then giveaways else null END as giveaways,
    CASE when Season>19970000 then takeaways else null END as takeaways, toi
from Skaters_temp4;

Create temporary table Skaters_temp5 
select Season, '' as last_season, SeasonState, Era_Adjusted, PlayerID, Position, COUNT(GameID) as GP, 
	COUNT(CASE when Season>19590000 then GameID else null END) as GP_after1959, 
    COUNT(CASE when shifts>0 then GameID else null END) as GP_after1997, 
	SUM(goals) as goals, SUM(CASE when Season>19590000 then goals else 0 END) as goals_after1959, 
    SUM(assists) as assists, SUM(points) as points, SUM(plusMinus) as plusMinus, 
    SUM(pim) as pim, SUM(hits) as hits, SUM(PPG) as PPG, SUM(sog) as sog, SUM(blockedShots) as blockedShots, 
    SUM(shifts) as shifts, SUM(giveaways) as giveaways, SUM(takeaways) as takeaways, SUM(toi) as toi
from nhl_skater_games_basic
Group by Season, SeasonState, PlayerID, Position, Era_Adjusted;

Create temporary table Skaters_temp6 select 'All' as Season, MAX(season) as last_season, SeasonState, Era_Adjusted, PlayerID, Position, SUM(GP) as GP, 
	SUM(GP_after1959) as GP_after1959, SUM(GP_after1997) as GP_after1997, 
	SUM(goals) as goals, SUM(goals_after1959) as goals_after1959, 
    SUM(assists) as assists, SUM(points) as points, SUM(plusMinus) as plusMinus, 
    SUM(pim) as pim, SUM(hits) as hits, SUM(PPG) as PPG, SUM(sog) as sog, SUM(blockedShots) as blockedShots, 
    SUM(shifts) as shifts, SUM(giveaways) as giveaways, SUM(takeaways) as takeaways, SUM(toi) as toi
from Skaters_temp5
Group by SeasonState, PlayerID, Position, Era_Adjusted;

Create temporary table Skaters_temp7 select * from Skaters_temp6
UNION ALL
select * from Skaters_temp5;

Create temporary table Skaters_temp8 select Season, last_season, SeasonState, Era_Adjusted, PlayerID, Position, GP, 
	goals/GP as goals, assists/GP as assists, points/GP as points, 
    plusMinus/GP_after1959 as plusMinus, pim/GP as pim, hits/GP_after1997 as hits, PPG/GP as PPG, 
    sog/GP_after1959 as sog, blockedShots/GP_after1997 as blockedShots, shifts/GP_after1997 as shifts, 
    giveaways/GP_after1997 as giveaways, takeaways/GP_after1997 as takeaways, toi/GP_after1997 as toi, 
    goals_after1959/sog as shot_perc, 'Per Game' as Totals_Rates 
from Skaters_temp7;

Create temporary table Skaters_temp9 select Season, last_season, SeasonState, Era_Adjusted, PlayerID, Position, 
	GP, goals, assists, points, plusMinus, pim, hits, PPG, sog, blockedShots, shifts, giveaways, takeaways, toi, 
	goals_after1959/sog as shot_perc, 'Totals' as Totals_Rates 
from Skaters_temp7 where PlayerID is not null
UNION ALL
select * from Skaters_temp8 where PlayerID is not null;

Create temporary table Skaters_temp10 select Season, SeasonState, Totals_Rates, Era_Adjusted, PlayerID, Position, 'Raw' as Raw_Percentiles,
	GP, goals, assists, points,
	CASE when Season>19590000 or last_season>19590000 then plusMinus else null END as plusMinus, pim, 
    CASE when Season>19970000 or last_season>19970000 then hits else null END as hits, PPG, 
    CASE when Season>19590000 or last_season>19590000 then sog else null END as sog,
    CASE when Season>19970000 or last_season>19970000 then blockedShots else null END as blockedShots,
    CASE when Season>19970000 or last_season>19970000 then shifts else null END as shifts,
    CASE when Season>19970000 or last_season>19970000 then giveaways else null END as giveaways,
    CASE when Season>19970000 or last_season>19970000 then takeaways else null END as takeaways, toi, shot_perc
from Skaters_temp9;

Create temporary table Skaters_temp11 select Season, SeasonState, Totals_Rates, Era_Adjusted, PlayerID, Position, 'Percentile' as Raw_Percentiles,
	1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by GP DESC)-1)/COUNT(GP) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as GP,
    1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by goals DESC)-1)/COUNT(goals) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as goals,
	1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by assists DESC)-1)/COUNT(assists) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as assists,
    1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by points DESC)-1)/COUNT(points) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as points,
    CASE when plusMinus is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by plusMinus DESC)-1)/COUNT(plusMinus) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as plusMinus,
    1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by pim DESC)-1)/COUNT(pim) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as pim,
    CASE when hits is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by hits DESC)-1)/COUNT(hits) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as hits,
    1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by PPG DESC)-1)/COUNT(PPG) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) as PPG,
    CASE when sog is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by sog DESC)-1)/COUNT(sog) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as sog,
    CASE when blockedShots is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by blockedShots DESC)-1)/COUNT(blockedShots) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as blockedShots,
    CASE when shifts is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by shifts DESC)-1)/COUNT(shifts) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as shifts,
    CASE when giveaways is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by giveaways DESC)-1)/COUNT(giveaways) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as giveaways,
    CASE when takeaways is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by takeaways DESC)-1)/COUNT(takeaways) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as takeaways,
    CASE when toi is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by toi DESC)-1)/COUNT(toi) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as toi,
    CASE when shot_perc is null then null else 1-(RANK() OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted order by shot_perc DESC)-1)/COUNT(shot_perc) OVER(partition by Position, SeasonState, Season, Totals_Rates, Era_Adjusted) END as shot_perc
from Skaters_temp10 
where (SeasonState='regular' and Season<>'All' and GP>=10) or (SeasonState='regular' and Season='All' and GP>=100) or 
	(SeasonState='playoffs' and Season<>'All' and GP>=3) or (SeasonState='playoffs' and Season='All' and GP>=15);

Create table nhl_skater_basic select * from Skaters_temp10
UNION ALL
select * from Skaters_temp11;

Create table NHL_SkaterSeasons select Season, SeasonState, PlayerID, Team 
from nhl_skater_games_basic
Group by Season, SeasonState, PlayerID, Team;

Create table NHL_CareerData select Season, leagueAbbrev as League, `teamName.default` as Team, PlayerID,
	CASE when gameTypeId=2 then 'regular' when gameTypeId=3 then 'playoffs' else '' END as SeasonState,
    gamesPlayed as GP, Goals, Assists, Points, PIM, plusMinus, gameWinningGoals as GWG, otGoals as OTG, 
    powerPlayGoals as PPG, powerPlayPoints as PPP, shorthandedGoals as SHG, shorthandedPoints as SHP,
    Shots, shootingPctg
from careerstats;