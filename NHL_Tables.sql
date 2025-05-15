# Create all the necessary tables. You don't need the backticks (`), but they are there because I've copied the scripts from existing tables.
# Usually many of the tables would be created more naturally from a select statement. 
CREATE TABLE `nhl_teams` (
  `Team` text,
  `TeamID` int DEFAULT NULL,
  `Name` text,
  `Logo` text,
  `Color` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_shifts` (
  `GameID` int DEFAULT NULL,
  `endTime` VARCHAR(5),
  `period` VARCHAR(1),
  `playerId` VARCHAR(7),
  `shiftNumber` VARCHAR(3),
  `startTime` VARCHAR(5),
  `teamAbbrev` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_bios` (
  `Season` int DEFAULT NULL,
  `BirthDate` text,
  `draftOverall` VARCHAR(3),
  `draftYear` VARCHAR(4),
  `height` VARCHAR(3),
  `Nationality` text,
  `playerId` int DEFAULT NULL,
  `shootsCatches` text,
  `weight` VARCHAR(3),
  `Position` varchar(1) NOT NULL DEFAULT '',
  `Name` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_gameresults` (
  `GameID` int DEFAULT NULL,
  `season` int DEFAULT NULL,
  `gameType` int DEFAULT NULL,
  `gameDate` text,
  `startTimeUTC` text,
  `gameState` text,
  `AwayTeam` text,
  `AwayScore` VARCHAR(3),
  `HomeTeam` text,
  `HomeScore` VARCHAR(3),
  `lastPeriodType` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_pbp` (
  `GameID` int DEFAULT NULL,
  `LINK_PBP` text,
  `eventId` int DEFAULT NULL,
  `Period` int DEFAULT NULL,
  `timeInPeriod` varchar(5),
  `situationCode` text,
  `homeTeamDefendingSide` text,
  `typeCode` int DEFAULT NULL,
  `typeDescKey` text,
  `sortOrder` int DEFAULT NULL,
  `eventOwnerTeamId` varchar(4),
  `losingPlayerId` varchar(7),
  `winningPlayerId` varchar(7),
  `xCoord` varchar(4),
  `yCoord` varchar(4),
  `zoneCode` text,
  `reason` text,
  `hittingPlayerId` varchar(7),
  `hitteePlayerId` varchar(7),
  `playerId` varchar(7),
  `shotType` text,
  `shootingPlayerId` varchar(7),
  `goalieInNetId` varchar(7),
  `awaySOG` varchar(4),
  `homeSOG` varchar(4),
  `blockingPlayerId` varchar(7),
  `scoringPlayerId` varchar(7),
  `scoringPlayerTotal` varchar(4),
  `assist1PlayerId` varchar(7),
  `assist1PlayerTotal` varchar(4),
  `assist2PlayerId` varchar(7),
  `assist2PlayerTotal` varchar(4),
  `awayScore` varchar(2),
  `homeScore` varchar(2),
  `secondaryReason` text,
  `typeCode.1` text,
  `descKey` text,
  `duration` varchar(2),
  `committedByPlayerId` varchar(7),
  `drawnByPlayerId` varchar(7),
  `servedByPlayerId` varchar(7)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_playerdata` (
  `BirthDate` text,
  `draftOverall` VARCHAR(3),
  `draftYear` VARCHAR(4),
  `height` VARCHAR(3),
  `Nationality` text,
  `playerId` int DEFAULT NULL,
  `Position` varchar(1) NOT NULL DEFAULT '',
  `shootsCatches` text,
  `Player` text,
  `weight` VARCHAR(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_playerdata_all` (
  `BirthDate` text,
  `draftOverall` VARCHAR(3),
  `draftYear` VARCHAR(4),
  `height` VARCHAR(3),
  `Nationality` text,
  `playerId` int DEFAULT NULL,
  `Position` varchar(1) NOT NULL DEFAULT '',
  `shootsCatches` text,
  `Player` text,
  `weight` VARCHAR(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_shiftindex` (
  `GameID` int DEFAULT NULL,
  `ShiftIndex` bigint unsigned NOT NULL,
  `Start` double DEFAULT NULL,
  `End` double DEFAULT NULL,
  `Duration` double DEFAULT NULL,
  `Away_StrengthState` varchar(3) DEFAULT NULL,
  `Home_StrengthState` varchar(3) DEFAULT NULL,
  `Home_Forwards_ID` longtext,
  `Home_Forwards` longtext,
  `Home_Defenders_ID` longtext,
  `Home_Defenders` longtext,
  `Home_Goalie_ID` mediumtext,
  `Home_Goalie` text,
  `Away_Forwards_ID` longtext,
  `Away_Forwards` longtext,
  `Away_Defenders_ID` longtext,
  `Away_Defenders` longtext,
  `Away_Goalie_ID` mediumtext,
  `Away_Goalie` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `boxid_coordinates` (
  `x` int DEFAULT NULL,
  `y` int DEFAULT NULL,
  `BoxID` text,
  `BoxID_rev` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `boxid_size` (
  `BoxID` text,
  `BoxID_rev` text,
  `Size` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `nhl_schedule` (
  `GameID` int DEFAULT NULL,
  `Season` int DEFAULT NULL,
  `SeasonState` varchar(8) NOT NULL DEFAULT '',
  `Date` text,
  `StartTime` text,
  `gameState` text,
  `AwayTeam` text,
  `AwayScore` VARCHAR(3),
  `HomeTeam` text,
  `HomeScore` VARCHAR(3),
  `lastPeriodType` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `pbpdata_before_xg` (
  `GameID` int DEFAULT NULL,
  `Season` int DEFAULT NULL,
  `SeasonState` varchar(8) NOT NULL DEFAULT '',
  `Venue` varchar(4) NOT NULL DEFAULT '',
  `Period` int DEFAULT NULL,
  `gameTime` double DEFAULT NULL,
  `StrengthState` varchar(3) NOT NULL DEFAULT '',
  `typeCode` int DEFAULT NULL,
  `Event` text,
  `x` varchar(4) NOT NULL DEFAULT '',
  `y` varchar(4) NOT NULL DEFAULT '',
  `Zone` longtext,
  `reason` text,
  `shotType` text,
  `secondaryReason` text,
  `typeCode2` text,
  `PEN_duration` text,
  `EventTeam` longtext NOT NULL,
  `Goalie_ID` varchar(7),
  `Goalie` text,
  `Player1_ID` double DEFAULT NULL,
  `Player1` text,
  `Player2_ID` double DEFAULT NULL,
  `Player2` text,
  `Player3_ID` double DEFAULT NULL,
  `Player3` text,
  `Corsi` int NOT NULL DEFAULT '0',
  `Fenwick` int NOT NULL DEFAULT '0',
  `Shot` int NOT NULL DEFAULT '0',
  `Goal` int NOT NULL DEFAULT '0',
  `EventIndex` bigint unsigned NOT NULL,
  `ShiftIndex` bigint unsigned,
  `ScoreState` decimal(34,0) DEFAULT NULL,
  `Home_Forwards_ID` longtext,
  `Home_Forwards` longtext,
  `Home_Defenders_ID` longtext,
  `Home_Defenders` longtext,
  `Home_Goalie_ID` mediumtext,
  `Home_Goalie` text,
  `Away_Forwards_ID` longtext,
  `Away_Forwards` longtext,
  `Away_Defenders_ID` longtext,
  `Away_Defenders` longtext,
  `Away_Goalie_ID` mediumtext,
  `Away_Goalie` text,
  `BoxID` text,
  `BoxID_rev` text,
  `BoxSize` int DEFAULT NULL,
  `ShotDistance` varchar(22) DEFAULT NULL,
  `ShotAngle` varchar(22) DEFAULT NULL,
  `shotType2` longtext,
  `ScoreState2` decimal(34,0) DEFAULT NULL,
  `RinkVenue` longtext,
  `StrengthState2` varchar(3) DEFAULT '',
  `LastEvent` varchar(7) DEFAULT '',
  `LastEventTeam` varchar(4) DEFAULT '',
  `Position` varchar(1) DEFAULT '',
  `Shoots` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;