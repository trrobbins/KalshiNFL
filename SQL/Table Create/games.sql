-- NFLFastR game data

USE [NFLPrediction]
GO

/****** Object:  Table [dbo].[games]    Script Date: 5/26/2026 3:04:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[games](
	[game_id] [varchar](20) NOT NULL,
	[game_type] [char](4) NOT NULL,
	[gameday] [date] NOT NULL,
	[weekday] [varchar](10) NOT NULL,
	[home_team] [varchar](3) NOT NULL,
	[away_team] [varchar](3) NOT NULL,
	[home_moneyline] [int] NOT NULL,
	[away_moneyline] [int] NOT NULL,
	[home_score] [tinyint] NULL,
	[away_score] [tinyint] NULL,
 CONSTRAINT [PK_CompleteGames] PRIMARY KEY CLUSTERED 
(
	[game_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO



/****** Object:  Index [PK_CompleteGames]    Script Date: 5/26/2026 3:05:56 PM ******/
ALTER TABLE [dbo].[games] ADD  CONSTRAINT [PK_CompleteGames] PRIMARY KEY CLUSTERED 
(
	[game_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

