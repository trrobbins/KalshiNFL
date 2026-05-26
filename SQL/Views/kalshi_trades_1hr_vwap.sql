-- Returns trade data aggregated to 1 hr intervals.  Dramatically reduces the number of records returned.  

USE [NFLPrediction]
GO

/****** Object:  View [dbo].[kalshi_trades_1hr_vwap]    Script Date: 5/26/2026 3:22:16 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [dbo].[kalshi_trades_1hr_vwap]
AS
SELECT
    kt.ticker,
    kt.game,
    gm.game_id,
    kt.event_date,
    kt.contract_team,

    -- Hour bucket start timestamp (UTC)
    DATEADD(hour, DATEDIFF(hour, 0, kt.created_time), 0) AS trade_hour,
    kt.taker_side,

    SUM(kt.[count]) AS total_count,

    -- aggregated dollar volume in that 1-hr bucket
    SUM(kt.dollar_volume) AS total_dollar_volume,

    -- volume-weighted prices (same names as your 1-min view)
    SUM(kt.price * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_price,
    SUM(kt.yes_price * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_yes_price,
    SUM(kt.no_price  * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_no_price,

    SUM(kt.yes_price_dollars * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_yes_price_dollars,
    SUM(kt.no_price_dollars  * kt.[count]) / NULLIF(SUM(kt.[count]), 0) AS vwap_no_price_dollars,

    -- High / Low within the hour (additive columns)
    MAX(kt.price)              AS high_price,
    MIN(kt.price)              AS low_price,

    MAX(kt.yes_price)          AS high_yes_price,
    MIN(kt.yes_price)          AS low_yes_price,

    MAX(kt.no_price)           AS high_no_price,
    MIN(kt.no_price)           AS low_no_price,

    MAX(kt.yes_price_dollars)  AS high_yes_price_dollars,
    MIN(kt.yes_price_dollars)  AS low_yes_price_dollars,

    MAX(kt.no_price_dollars)   AS high_no_price_dollars,
    MIN(kt.no_price_dollars)   AS low_no_price_dollars

FROM dbo.kalshi_trades AS kt
LEFT JOIN dbo.gamemap AS gm
    ON kt.game = gm.game

GROUP BY
    kt.ticker,
    kt.game,
    gm.game_id,
    kt.event_date,
    kt.contract_team,
    DATEADD(hour, DATEDIFF(hour, 0, kt.created_time), 0),
    kt.taker_side;
GO


