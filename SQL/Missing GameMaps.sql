WITH MissingGames AS (
    SELECT
        kt.game,

        DATEFROMPARTS(
            2000 + CAST(SUBSTRING(kt.game, CHARINDEX('-', kt.game) + 1, 2) AS int),
            CASE SUBSTRING(kt.game, CHARINDEX('-', kt.game) + 3, 3)
                WHEN 'JAN' THEN 1
                WHEN 'FEB' THEN 2
                WHEN 'MAR' THEN 3
                WHEN 'APR' THEN 4
                WHEN 'MAY' THEN 5
                WHEN 'JUN' THEN 6
                WHEN 'JUL' THEN 7
                WHEN 'AUG' THEN 8
                WHEN 'SEP' THEN 9
                WHEN 'OCT' THEN 10
                WHEN 'NOV' THEN 11
                WHEN 'DEC' THEN 12
            END,
            CAST(SUBSTRING(kt.game, CHARINDEX('-', kt.game) + 6, 2) AS int)
        ) AS kalshi_game_date,

        kt.created_time

    FROM NFLPrediction.dbo.kalshi_trades AS kt
    LEFT JOIN NFLPrediction.dbo.gamemap AS gm
        ON kt.game = gm.game
    WHERE gm.game IS NULL
)

SELECT
    game,
    kalshi_game_date,
    COUNT(*) AS TradeRows,
    MIN(created_time) AS FirstTradeTime,
    MAX(created_time) AS LastTradeTime
FROM MissingGames
WHERE kalshi_game_date >= '2025-09-04'
GROUP BY
    game,
    kalshi_game_date
ORDER BY
    kalshi_game_date,
    game;