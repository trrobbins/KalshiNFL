-- Mapping Kalshi tickers to NFLfastR game ids


USE [NFLPrediction]
GO

/****** Object:  Table [dbo].[gamemap]    Script Date: 5/26/2026 3:02:26 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[gamemap](
	[game] [varchar](30) NOT NULL,
	[game_id] [varchar](20) NOT NULL
) ON [PRIMARY]
GO

USE [NFLPrediction]
GO

SET ANSI_PADDING ON
GO

/****** Object:  Index [IX_gamemap_game]    Script Date: 5/26/2026 3:02:40 PM ******/
CREATE NONCLUSTERED INDEX [IX_gamemap_game] ON [dbo].[gamemap]
(
	[game] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

USE [NFLPrediction]
GO

SET ANSI_PADDING ON
GO

/****** Object:  Index [IX_gamemap_game_id]    Script Date: 5/26/2026 3:02:50 PM ******/
CREATE NONCLUSTERED INDEX [IX_gamemap_game_id] ON [dbo].[gamemap]
(
	[game_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO


