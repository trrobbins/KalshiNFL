
-- THis view gets the winner of each game and include both Kalshi and NFLFastR keys

USE [NFLPrediction]
GO

/****** Object:  View [dbo].[game_winners]    Script Date: 5/26/2026 3:14:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[game_winners]
AS
SELECT
    g.[game_id],
    gm.[game],              -- from gamemap
    g.[game_type],
    g.[gameday],
    g.[weekday],
    g.[home_team],
    g.[away_team],
    g.[home_moneyline],
    g.[away_moneyline],
    g.[home_score],
    g.[away_score],

    CASE
        WHEN g.[home_score] > g.[away_score] THEN g.[home_team]
        WHEN g.[home_score] < g.[away_score] THEN g.[away_team]
        ELSE NULL
    END AS [winner],

    CASE
        WHEN g.[home_score] = g.[away_score] THEN 1
        ELSE 0
    END AS [tie]
FROM [dbo].[games] g
LEFT JOIN [dbo].[gamemap] gm
    ON gm.[game_id] = g.[game_id];
GO


