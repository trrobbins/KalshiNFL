-- Raw Trade data from Kalshi


USE [NFLPrediction]
GO

/****** Object:  Table [dbo].[kalshi_trades_raw]    Script Date: 5/26/2026 3:08:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[kalshi_trades_raw](
	[count] [int] NULL,
	[created_time] [datetime2](7) NULL,
	[no_price] [tinyint] NULL,
	[no_price_dollars] [decimal](5, 2) NULL,
	[price] [decimal](5, 2) NULL,
	[taker_side] [varchar](5) NULL,
	[ticker] [nvarchar](100) NULL,
	[trade_id] [uniqueidentifier] NULL,
	[yes_price] [tinyint] NULL,
	[yes_price_dollars] [decimal](5, 2) NULL
) ON [PRIMARY]
GO


USE [NFLPrediction]
GO

SET ANSI_PADDING ON
GO

/****** Object:  Index [CX_kalshi_trades_ticker_time]    Script Date: 5/26/2026 3:10:03 PM ******/
CREATE CLUSTERED INDEX [CX_kalshi_trades_ticker_time] ON [dbo].[kalshi_trades_raw]
(
	[ticker] ASC,
	[created_time] ASC,
	[trade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

USE [NFLPrediction]
GO

/****** Object:  Index [IX_kalshi_trades_trade_id]    Script Date: 5/26/2026 3:10:14 PM ******/
CREATE NONCLUSTERED INDEX [IX_kalshi_trades_trade_id] ON [dbo].[kalshi_trades_raw]
(
	[trade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

USE [NFLPrediction]
GO

/****** Object:  Index [UX_kalshi_trades_raw_trade_id]    Script Date: 5/26/2026 3:10:23 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_kalshi_trades_raw_trade_id] ON [dbo].[kalshi_trades_raw]
(
	[trade_id] ASC
)
WHERE ([trade_id] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

