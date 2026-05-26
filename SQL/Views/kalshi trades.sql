-- Returns raw trade daat with fields parsed.  

USE [NFLPrediction]
GO

/****** Object:  View [dbo].[kalshi_trades]    Script Date: 5/26/2026 3:17:42 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[kalshi_trades]
AS
SELECT
    r.[count],
    r.created_time,
    r.no_price,
    r.no_price_dollars,
    r.price,
    r.taker_side,
    r.ticker,
    r.trade_id,
    r.yes_price,
    r.yes_price_dollars,

    dollar_volume =
        CAST(r.[count] AS decimal(18, 2)) *
        CASE
            WHEN LOWER(r.taker_side) = 'yes' THEN CAST(r.yes_price_dollars AS decimal(18, 2))
            WHEN LOWER(r.taker_side) = 'no'  THEN CAST(r.no_price_dollars  AS decimal(18, 2))
            ELSE NULL
        END,

    -- derived fields (all lowercase)
    series = LEFT(r.ticker, d.pos1 - 1),

    game = LEFT(r.ticker, d.pos2 - 1),

    event_date = TRY_CONVERT(
                     date,
                     CONCAT(
                         RIGHT(dc.datecode, 2), ' ',
                         SUBSTRING(dc.datecode, 3, 3), ' ',
                         '20', LEFT(dc.datecode, 2)
                     ),
                     106
                 ),

    matchup = SUBSTRING(
                  r.ticker,
                  d.pos1 + 8,
                  d.pos2 - (d.pos1 + 8)
              ),

    contract_team = SUBSTRING(
                        r.ticker,
                        d.pos2 + 1,
                        LEN(r.ticker) - d.pos2
                    )
FROM dbo.kalshi_trades_raw AS r
CROSS APPLY (
    SELECT
        CHARINDEX('-', r.ticker) AS pos1,
        CHARINDEX('-', r.ticker, CHARINDEX('-', r.ticker) + 1) AS pos2
) AS d
CROSS APPLY (
    SELECT SUBSTRING(r.ticker, d.pos1 + 1, 7) AS datecode
) AS dc;
GO


