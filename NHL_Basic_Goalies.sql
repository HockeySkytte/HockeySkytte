# Select the Schema/Database you created earlier
use public;

# Truncate tables before loading CSV data into them
truncate NHL_goalies;
truncate careerstats_G;

# Load data from CSV files into MySQL tables
load data infile
'C:/Public/NHL/Goalies.csv'
into table NHL_goalies
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

load data infile
'C:/Public/NHL/careerStats_G.csv'
into table careerstats_G
FIELDS
    TERMINATED BY ','
  LINES
    TERMINATED BY '\r\n'
  IGNORE 1 LINES;

Create temporary table Goalies_temp1 select Season, SeasonState, left(Date,10) as Date, s.GameID, Venue, 
	CASE when Venue='Away' then AwayTeam when Venue='Home' then HomeTeam else '' END as Team,
    CASE when Venue='Home' then AwayTeam when Venue='Away' then HomeTeam else '' END as Opponent,
    PlayerId, evenStrengthGoalsAgainst as EVGA, powerPlayGoalsAgainst as PPGA, shorthandedGoalsAgainst as SHGA, 
    CASE when Season<19970000 then null else SUBSTRING_INDEX(evenStrengthShotsAgainst, '/', -1) END as EVSA, 
    CASE when Season<19970000 then null else SUBSTRING_INDEX(powerPlayShotsAgainst, '/', -1) END as PPSA, 
    CASE when Season<19970000 then null else SUBSTRING_INDEX(shorthandedShotsAgainst, '/', -1) END as SHSA, 
    goalsAgainst as GA, 
    CASE when Season<19550000 then null else SUBSTRING_INDEX(ShotsAgainst, '/', -1) END as SA, pim, 
	CASE when toi<>'' then left(toi,2) + right(toi,2)/60 else null END as TOI
from NHL_Goalies as s
left join NHL_Schedule as g
	on s.GameID=g.GameID;

Create temporary table Goalies_temp2 select Season, SeasonState, Date, GameID, Venue, Team, Opponent, p.PlayerID, Birthday,
	row_number() over(partition by p.PlayerID, SeasonState order by GameID) as Game_No,
	EVGA, PPGA, SHGA, EVSA, PPSA, SHSA, GA, SA, pim, TOI
from Goalies_temp1 as s
left join NHL_Players as p
	on s.PlayerId=p.PlayerID
where TOI>0
Order by GameID, Venue, p.PlayerID;

Create temporary table Averages_temp1 select Season, COUNT(distinct GameID) as GP, SUM(TOI) as TOI,
	SUM(EVGA) as EVGA, SUM(PPGA) as PPGA, SUM(SHGA) as SHGA, SUM(EVSA) as EVSA, SUM(PPSA) as PPSA, SUM(SHSA) as SHSA,
    SUM(GA) as GA, SUM(SA) as SA, SUM(pim) as pim, (SUM(SA)-SUM(GA))/SUM(SA) as save_perc
from Goalies_temp2
Group by Season;

Create temporary table Averages_temp2 select Season, EVGA/TOI as EVGA, PPGA/TOI as PPGA, SHGA/TOI as SHGA, 
	EVSA/TOI as EVSA, PPSA/TOI as PPSA, SHSA/TOI as SHSA, GA/TOI as GA, SA/TOI as SA, pim/TOI as pim, save_perc
from Averages_temp1;

Create temporary table Averages_temp3 select EVGA/TOI as EVGA, PPGA/TOI as PPGA, SHGA/TOI as SHGA, 
	EVSA/TOI as EVSA, PPSA/TOI as PPSA, SHSA/TOI as SHSA, GA/TOI as GA, SA/TOI as SA, pim/TOI as pim, save_perc
from Averages_temp1
Where Season=20242025;

Create temporary table Averages_temp4 select Season, a2.EVGA/a1.EVGA as EVGA, a2.PPGA/a1.PPGA as PPGA, a2.SHGA/a1.SHGA as SHGA, 
	a2.EVSA/a1.EVSA as EVSA, a2.PPSA/a1.PPSA as PPSA, a2.SHSA/a1.SHSA as SHSA, a2.GA/a1.GA as GA, a2.SA/a1.SA as SA, a2.pim/a1.pim as pim,
    a2.save_perc/a1.save_perc as save_perc
from Averages_temp2 as a1
left join Averages_temp3 as a2
	on 1=1;

Create table NHL_Goalie_Era_adjustments select Season, GA, SA, PIM, save_perc
from Averages_temp4;

Create temporary table Goalies_temp3 select s.Season, s.SeasonState, Date, GameID, Venue, Team, Opponent, PlayerID, Birthday, Game_No,
    s.EVGA*a.EVGA as EVGA, s.PPGA*a.PPGA as PPGA, s.SHGA*a.SHGA as SHGA, 
    s.EVSA*a.EVSA as EVSA, s.PPSA*a.PPSA as PPSA, s.SHSA*a.SHSA as SHSA, 
    s.GA*a.GA as GA, s.SA*a.SA as SA, s.pim*a.pim as pim, TOI, 'Adjusted' as Era_Adjusted
from Goalies_temp2 as s
left join Averages_temp4 as a
	on s.Season=a.Season;

Create temporary table Goalies_Temp3_2 select *, 'Raw' as Era_Adjusted from Goalies_temp2
UNION ALL
select * from Goalies_temp3;

Create temporary table Goalies_temp3_avg 
select Season, Era_Adjusted, 1-SUM(GA)/SUM(SA) as avg_sav_perc
from Goalies_temp3_2
where SA>0
group by Season, Era_Adjusted;

Create temporary table Goalies_temp3_GSAA 
select g.Season, SeasonState, Date, GameID, Venue, Team, Opponent, PlayerID, Birthday, Game_No, 
	EVGA, PPGA, SHGA, EVSA, PPSA, SHSA, GA, SA, pim, TOI, g.Era_Adjusted, 
    (1-GA/SA - avg_sav_perc)*SA as GSAA
from Goalies_temp3_2 as g
left join Goalies_temp3_avg as a
	on g.Season=a.Season and g.Era_Adjusted=a.Era_Adjusted;

Create table nhl_goalie_games_basic select *, 'Raw' as Era_Adjusted from Goalies_temp2
UNION ALL
select * from Goalies_temp3;

Create temporary table Goalies_temp4 select Season, '' as last_season, SeasonState, Era_Adjusted, PlayerID, COUNT(GameID) as GP, 
	COUNT(CASE when SA>0 then GameID else null END) as GP_after1955, 
    COUNT(CASE when EVSA>0 then GameID else null END) as GP_after1997, 
	SUM(EVGA) as EVGA, SUM(CASE when EVSA>0 then EVGA else 0 END) as EVGA_after1997, 
    SUM(PPGA) as PPGA, SUM(CASE when EVSA>0 then PPGA else 0 END) as PPGA_after1997, 
    SUM(SHGA) as SHGA, SUM(CASE when EVSA>0 then SHGA else 0 END) as SHGA_after1997, 
    SUM(EVSA) as EVSA, SUM(PPSA) as PPSA, SUM(SHSA) as SHSA, SUM(GA) as GA, SUM(CASE when SA>0 then GA else 0 END) as GA_after1955, 
    SUM(SA) as SA, SUM(pim) as pim, SUM(TOI) as TOI, SUM(CASE when SA>0 then GSAA else 0 END) as GSAA
from nhl_goalie_games_basic
Group by Season, SeasonState, PlayerID, Era_Adjusted;

Create temporary table Goalies_temp5 select 'All' as Season, MAX(season) as last_season, SeasonState, Era_Adjusted, PlayerID, SUM(GP) as GP, 
	SUM(GP_after1955) as GP_after1955, SUM(GP_after1997) as GP_after1997, 
	SUM(EVGA) as EVGA, SUM(EVGA_after1997) as EVGA_after1997, 
    SUM(PPGA) as PPGA, SUM(PPGA_after1997) as PPGA_after1997, 
    SUM(SHGA) as SHGA, SUM(SHGA_after1997) as SHGA_after1997, 
    SUM(EVSA) as EVSA, SUM(PPSA) as PPSA, SUM(SHSA) as SHSA, SUM(GA) as GA,
    SUM(GA_after1955) as GA_after1955, SUM(SA) as SA, 
    SUM(pim) as pim, SUM(TOI) as TOI, SUM(GSAA) as GSAA
from Goalies_temp4
Group by SeasonState, PlayerID, Era_Adjusted;

Create temporary table Goalies_temp6 select * from Goalies_temp4
UNION ALL
select * from Goalies_temp5;

Create temporary table Goalies_temp7 select Season, SeasonState, Era_Adjusted, PlayerID, 'Raw' as Raw_Percentiles, GP, 
	EVGA/GP as EVGA, PPGA/GP as PPGA, SHGA/GP as SHGA, 
    EVSA/GP_after1997 as EVSA, PPSA/GP_after1997 as PPSA, SHSA/GP_after1997 as SHSA,
    GA/GP as GA, SA/GP_after1955 as SA, pim/GP as pim, TOI/GP as TOI,
    1-EVGA_after1997/EVSA as EV_save_perc, 1-PPGA_after1997/PPSA as PP_save_perc, 1-SHGA_after1997/SHSA as SH_save_perc, 
    1-GA_after1955/SA as save_perc, GSAA/GP_after1955 as GSAA,
	'Per Game' as Totals_Rates 
from Goalies_temp6;

Create temporary table Goalies_temp8
select Season, SeasonState, Era_Adjusted, PlayerID, 'Raw' as Raw_Percentiles,
	GP, EVGA, PPGA, SHGA, EVSA, PPSA, SHSA, GA, SA, pim, TOI, 
    1-EVGA_after1997/EVSA as EV_save_perc, 1-PPGA_after1997/PPSA as PP_save_perc, 1-SHGA_after1997/SHSA as SH_save_perc, 
    1-GA_after1955/SA as save_perc, GSAA,
	'Totals' as Totals_Rates 
from Goalies_temp6
UNION ALL
select * from Goalies_temp7;

Create temporary table Goalies_temp9 select Season, SeasonState, Era_Adjusted, PlayerID, 'Percentile' as Raw_Percentiles,
	1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by GP DESC)-1)/COUNT(GP) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as GP,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by EVGA DESC)-1)/COUNT(EVGA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as EVGA,
	1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by PPGA DESC)-1)/COUNT(PPGA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as PPGA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by SHGA DESC)-1)/COUNT(SHGA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as SHGA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by EVSA DESC)-1)/COUNT(EVSA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as EVSA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by PPSA DESC)-1)/COUNT(PPSA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as PPSA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by SHSA DESC)-1)/COUNT(SHSA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as SHSA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by GA DESC)-1)/COUNT(GA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as GA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by SA DESC)-1)/COUNT(SA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as SA,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by pim DESC)-1)/COUNT(pim) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as pim,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by TOI DESC)-1)/COUNT(TOI) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as TOI,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by EV_save_perc DESC)-1)/COUNT(EV_save_perc) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as EV_save_perc,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by PP_save_perc DESC)-1)/COUNT(PP_save_perc) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as PP_save_perc,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by SH_save_perc DESC)-1)/COUNT(SH_save_perc) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as SH_save_perc,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by save_perc DESC)-1)/COUNT(save_perc) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as save_perc,
    1-(RANK() OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted order by GSAA DESC)-1)/COUNT(GSAA) OVER(partition by SeasonState, Season, Totals_Rates, Era_Adjusted) as GSAA,
    Totals_Rates
from Goalies_temp8 
where (SeasonState='regular' and GP>=10) or (SeasonState='playoffs' and GP>=3);

Create table nhl_goalie_basic select * from Goalies_temp8
UNION ALL
select * from Goalies_temp9;

Create table NHL_GoalieSeasons select s.Season, s.SeasonState, s.PlayerID, s.Team, Player, Position, ShootsCatches, s.Birthday, Nationality,
	Height, Weight, DraftPosition, DraftYear
from nhl_Goalie_games_basic as s
left join nhl_players as p
	on s.PlayerID=p.PlayerID
Group by s.Season, s.SeasonState, s.PlayerID, s.Team, Player, Position, ShootsCatches, s.Birthday, Nationality,
	Height, Weight, DraftPosition, DraftYear;

Create table NHL_CareerData_G select Season, leagueAbbrev as League, `teamName.default` as Team, PlayerID,
	CASE when gameTypeId=2 then 'regular' when gameTypeId=3 then 'playoffs' else '' END as SeasonState,
    gamesPlayed as GP, goalsAgainst as GA, goalsAgainstAvg as GAA, Wins, Ties, Losses, savePctg, shotsAgainst as SA
from careerstats_G;