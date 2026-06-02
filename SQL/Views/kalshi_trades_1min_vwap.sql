-- Returns trade data aggregated to 1 min intervals.  Dramatically reduces the number of records returned.  

USE [NFLPrediction]
GO

/****** Object:  View [dbo].[kalshi_trades_1min_vwap]    Script Date: 5/26/2026 3:23:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE or ALTER VIEW [dbo].[kalshi_trades_1min_vwap]
AS
SELECT
    kt.ticker,
	kt.league,
    kt.game,
    gm.game_id,            -- NEW: from gamemap
    kt.event_date,
    kt.contract_team,

    DATEADD(minute, DATEDIFF(minute, 0, kt.created_time), 0) AS trade_minute,
    kt.taker_side,

    SUM(kt.[count]) AS total_count,

    -- aggregated dollar volume in that 1-min bucket
    SUM(kt.dollar_volume) AS total_dollar_volume,

    -- volume-weighted prices
    SUM(kt.price * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_price,
    SUM(kt.yes_price * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_yes_price,
    SUM(kt.no_price  * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_no_price,

    SUM(kt.yes_price_dollars * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_yes_price_dollars,
    SUM(kt.no_price_dollars  * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_no_price_dollars

FROM dbo.kalshi_trades AS kt
LEFT JOIN dbo.gamemap AS gm
    ON kt.game = gm.game

GROUP BY
    league,
    kt.ticker,
    kt.game,
    gm.game_id,            -- NEW: must be grouped
    kt.event_date,
    kt.contract_team,

    DATEADD(minute, DATEDIFF(minute, 0, kt.created_time), 0),
    kt.taker_side;
GO


