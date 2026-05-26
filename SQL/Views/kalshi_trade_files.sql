-- Gets a distinct set of downloaded file names

USE [NFLPrediction]
GO

/****** Object:  View [dbo].[kalshi_trade_files]    Script Date: 5/26/2026 3:15:52 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[kalshi_trade_files] AS
SELECT DISTINCT 
    ticker,
    CONCAT(ticker, '-Trades.csv') AS FName
FROM kalshi_trades_raw;
GO


