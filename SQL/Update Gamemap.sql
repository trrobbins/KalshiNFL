BULK INSERT dbo.gamemap
FROM 'C:\Users\Owner\Dropbox\ECU Misc\Active Working Papers\Prediction Markets\gamemap.csv'
WITH
(
    FIRSTROW = 2,              -- if your CSV has a header row
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',     -- LF; if Windows CRLF gives issues try '0x0d0a'
    TABLOCK,
    CODEPAGE = '65001'          -- UTF-8 (safe default)
);

UPDATE dbo.gamemap
SET
    game    = REPLACE(game, '"', ''),
    game_id = REPLACE(game_id, '"', '');

	
UPDATE NFLPrediction.dbo.gamemap
SET
    game_id = REPLACE(REPLACE(game_id, CHAR(13), ''), CHAR(10), ''),
    game    = REPLACE(REPLACE(game,    CHAR(13), ''), CHAR(10), '');


