import os
import pandas as pd
from datetime import datetime
import re
import numpy as np


# Map team codes to readable names.
TEAM_MAP = {
    "ARI":"Cardinals","ATL":"Falcons","BAL":"Ravens","BUF":"Bills","CAR":"Panthers","CHI":"Bears",
    "CIN":"Bengals","CLE":"Browns","DAL":"Cowboys","DEN":"Broncos","DET":"Lions","GB":"Packers",
    "HOU":"Texans","IND":"Colts","JAX":"Jaguars","JAC":"Jaguars","KC":"Chiefs",
    "LAC":"Chargers","LA":"Los Angeles","LAR":"Rams","LV":"Raiders",
    "MIA":"Dolphins","MIN":"Vikings","NE":"Patriots","NO":"Saints",
    "NYG":"Giants","NYJ":"Jets","PHI":"Eagles","PIT":"Steelers",
    "SEA":"Seahawks","SF":"49ers","TB":"Buccaneers","TEN":"Titans","WAS":"Commanders"
}


# Allow both 2-letter and 3-letter codes.
# We'll try to match longer codes first to avoid splitting "LAC" as "LA" + "C".
VALID_CODES = sorted(TEAM_MAP.keys(), key=len, reverse=True)


NBA_TEAM_MAP = {
    "ATL": "Hawks", "BOS": "Celtics", "BKN": "Nets", "CHA": "Hornets",
    "CHI": "Bulls", "CLE": "Cavaliers", "DAL": "Mavericks", "DEN": "Nuggets",
    "DET": "Pistons", "GSW": "Warriors", "HOU": "Rockets", "IND": "Pacers",
    "LAC": "Clippers", "LAL": "Lakers", "MEM": "Grizzlies", "MIA": "Heat",
    "MIL": "Bucks", "MIN": "Timberwolves", "NOP": "Pelicans", "NYK": "Knicks",
    "OKC": "Thunder", "ORL": "Magic", "PHI": "76ers", "PHX": "Suns",
    "POR": "Trail Blazers", "SAC": "Kings", "SAS": "Spurs", "TOR": "Raptors",
    "UTA": "Jazz", "WAS": "Wizards",
}

NBA_VALID_CODES = sorted(NBA_TEAM_MAP.keys(), key=len, reverse=True)


NHL_TEAM_MAP = {
    "ANA": "Ducks", "BOS": "Bruins", "BUF": "Sabres", "CAR": "Hurricanes",
    "CBJ": "Blue Jackets", "CGY": "Flames", "CHI": "Blackhawks",
    "COL": "Avalanche", "DAL": "Stars", "DET": "Red Wings",
    "EDM": "Oilers", "FLA": "Panthers", "LAK": "Kings", "MIN": "Wild",
    "MTL": "Canadiens", "NJD": "Devils", "NSH": "Predators",
    "NYI": "Islanders", "NYR": "Rangers", "OTT": "Senators",
    "PHI": "Flyers", "PIT": "Penguins", "SEA": "Kraken",
    "SJS": "Sharks", "STL": "Blues", "TBL": "Lightning",
    "TOR": "Maple Leafs", "UTA": "Mammoth", "VAN": "Canucks",
    "VGK": "Golden Knights", "WPG": "Jets", "WSH": "Capitals",
    "WAS": "Capitals",
}

NHL_VALID_CODES = sorted(NHL_TEAM_MAP.keys(), key=len, reverse=True)


MLB_TEAM_MAP = {
    "ARI": "Diamondbacks", "ATH": "Athletics", "ATL": "Braves",
    "BAL": "Orioles", "BOS": "Red Sox", "CHC": "Cubs",
    "CIN": "Reds", "CLE": "Guardians", "COL": "Rockies",
    "CWS": "White Sox", "DET": "Tigers", "HOU": "Astros",
    "KC": "Royals", "KCR": "Royals", "LAA": "Angels",
    "LAD": "Dodgers", "MIA": "Marlins", "MIL": "Brewers",
    "MIN": "Twins", "NYM": "Mets", "NYY": "Yankees",
    "OAK": "Athletics", "PHI": "Phillies", "PIT": "Pirates",
    "SD": "Padres", "SDP": "Padres", "SEA": "Mariners",
    "SF": "Giants", "SFG": "Giants", "STL": "Cardinals",
    "TB": "Rays", "TBR": "Rays", "TEX": "Rangers",
    "TOR": "Blue Jays", "WAS": "Nationals", "WSH": "Nationals",
}

MLB_VALID_CODES = sorted(MLB_TEAM_MAP.keys(), key=len, reverse=True)


NCAAF_TEAM_MAP = {
    "ALA": "Alabama", "APP": "Appalachian State", "ARIZ": "Arizona",
    "ARK": "Arkansas", "ARMY": "Army", "ASU": "Arizona State",
    "AUB": "Auburn", "BAY": "Baylor", "BC": "Boston College",
    "BOIS": "Boise State", "BYU": "BYU", "CAL": "California",
    "CLEM": "Clemson", "CIN": "Cincinnati", "COLO": "Colorado",
    "DUKE": "Duke", "ECU": "East Carolina", "FLA": "Florida",
    "FSU": "Florida State", "GT": "Georgia Tech", "HOU": "Houston",
    "ILL": "Illinois", "IND": "Indiana", "IOWA": "Iowa",
    "ISU": "Iowa State", "JMU": "James Madison", "KAN": "Kansas",
    "KSU": "Kansas State", "LSU": "LSU", "LOU": "Louisville",
    "MICH": "Michigan", "MINN": "Minnesota", "MISS": "Ole Miss",
    "M-OH": "Miami (OH)", "MIZ": "Missouri", "MSST": "Mississippi State", "NAVY": "Navy",
    "NCST": "NC State", "NEB": "Nebraska", "ND": "Notre Dame",
    "NW": "Northwestern", "OHIO": "Ohio", "OKLA": "Oklahoma",
    "OKST": "Oklahoma State", "ORE": "Oregon", "OSU": "Ohio State",
    "PSU": "Penn State", "PUR": "Purdue", "RICE": "Rice",
    "RUTG": "Rutgers", "SC": "South Carolina", "SMU": "SMU",
    "STAN": "Stanford", "SYR": "Syracuse", "TCU": "TCU",
    "TENN": "Tennessee", "TEX": "Texas", "TULN": "Tulane",
    "TTU": "Texas Tech", "UCF": "UCF", "UCLA": "UCLA", "FRES": "Fresno State",
    "UNC": "North Carolina", "UNLV": "UNLV", "USC": "USC",
    "USF": "South Florida", "UTAH": "Utah", "UTSA": "UTSA",
    "UVA": "Virginia", "VT": "Virginia Tech", "WAKE": "Wake Forest",
    "WASH": "Washington", "WISC": "Wisconsin", "WVU": "West Virginia",
}

NCAAF_VALID_CODES = sorted(NCAAF_TEAM_MAP.keys(), key=len, reverse=True)


def split_teams_blob(blob: str):
    """
    Given something like 'MINLAC', 'TBNO', 'JACLV', return (away_code, home_code).

    We try every known team code as a prefix and see if the remainder
    is also a known code.
    """
    for away in VALID_CODES:
        if blob.startswith(away):
            home_candidate = blob[len(away):]
            if home_candidate in VALID_CODES:
                return away, home_candidate
    return None, None


def split_nba_teams_blob(blob: str):
    """
    Given something like 'NYKSAS', return (away_code, home_code).
    """
    for away in NBA_VALID_CODES:
        if blob.startswith(away):
            home_candidate = blob[len(away):]
            if home_candidate in NBA_VALID_CODES:
                return away, home_candidate
    return None, None


def split_nhl_teams_blob(blob: str):
    """
    Given something like 'VGKCAR', return (away_code, home_code).
    """
    for away in NHL_VALID_CODES:
        if blob.startswith(away):
            home_candidate = blob[len(away):]
            if home_candidate in NHL_VALID_CODES:
                return away, home_candidate
    return None, None


def split_mlb_teams_blob(blob: str):
    """
    Given something like 'DETTB', return (away_code, home_code).
    """
    for away in MLB_VALID_CODES:
        if blob.startswith(away):
            home_candidate = blob[len(away):]
            if home_candidate in MLB_VALID_CODES:
                return away, home_candidate
    if len(blob) % 2 == 0:
        mid = len(blob) // 2
        return blob[:mid], blob[mid:]
    return None, None


def split_ncaaf_teams_blob(blob: str):
    """
    Given something like 'UNCTCU', return (away_code, home_code).

    College team codes are less standardized than pro leagues, so known codes
    are tried first. If both sides are unknown and the blob is an even length,
    fall back to a symmetric split so the date and matchup are still usable.
    """
    for away in NCAAF_VALID_CODES:
        if blob.startswith(away):
            home_candidate = blob[len(away):]
            if home_candidate in NCAAF_VALID_CODES:
                return away, home_candidate

    if len(blob) % 2 == 0:
        mid = len(blob) // 2
        return blob[:mid], blob[mid:]

    return None, None


def split_ncaaf_body_and_selection(body: str):
    """
    Split the post-date CFB ticker body into matchup blob and selection code.
    """
    for sel in NCAAF_VALID_CODES:
        suffix = f"-{sel}"
        if body.endswith(suffix):
            return body[:-len(suffix)], sel

    return body, None


def parse_kxnflgame_ticker(ticker: str):
    """
    Parse Kalshi NFL tickers like:
      KXNFLGAME-25OCT23MINLAC-LAC
      KXNFLGAME-25OCT26TBNO-NO

    Returns dict with:
      series
      GameDate (YYYY-MM-DD)
      Away, Home (team codes like MIN, LAC, TB, NO)
      AwayName, HomeName (pretty team names)
      Selection (code of the team this market is on, e.g. LAC)
      SelectionName (pretty name of that team)
      Matchup ("Vikings @ Chargers", etc.)
    """

    # Pattern:
    #   <series>-<YY><MON><DD><teams_blob>-<sel>
    # where teams_blob is both team codes jammed together, no delimiter.
    m = re.fullmatch(
        r"(KXNFLGAME)-"        # 1: series
        r"(\d{2})"             # 2: YY
        r"([A-Z]{3})"          # 3: MON (3-letter month)
        r"(\d{2})"             # 4: DD
        r"([A-Z]+)"            # 5: teams_blob (variable length, like MINLAC or TBNO)
        r"-([A-Z]{2,3})"       # 6: selection team code
        ,
        ticker
    )

    if not m:
        raise ValueError(f"Unrecognized ticker format: {ticker}")

    series, yy, mon, dd, teams_blob, sel = m.groups()

    # Build full date like 2025-10-23
    month_num = datetime.strptime(mon, "%b").month  # OCT -> 10
    year_full = 2000 + int(yy)
    game_date = f"{year_full:04d}-{month_num:02d}-{int(dd):02d}"

    # Split teams blob into away/home using known NFL codes
    away_code, home_code = split_teams_blob(teams_blob)

    # Create display fields
    away_name = TEAM_MAP.get(away_code, away_code)
    home_name = TEAM_MAP.get(home_code, home_code)
    sel_name  = TEAM_MAP.get(sel, sel)

    matchup = None
    if away_code and home_code:
        matchup = f"{away_name} @ {home_name}"

    return {
        "series": series,
        "GameDate": game_date,
        "Away": away_code,
        "Home": home_code,
        "AwayName": away_name,
        "HomeName": home_name,
        "Selection": sel,
        "SelectionName": sel_name,
        "Matchup": matchup
    }


def parse_kxncaafgame_ticker(ticker: str):
    """
    Parse Kalshi college football tickers like:
      KXNCAAFGAME-26AUG29UNCTCU
      KXNCAAFGAME-26AUG29UNCTCU-TCU
      KXNCAAFGAME-25DEC27M-OHFRES-M-OH

    Returns dict with:
      series
      GameDate (YYYY-MM-DD)
      Away, Home
      AwayName, HomeName
      Selection, SelectionName
      Matchup
    """
    ticker = ticker.upper()
    m = re.fullmatch(
        r"(KXNCAAFGAME)-"
        r"(\d{2})"
        r"([A-Z]{3})"
        r"(\d{2})"
        r"([A-Z-]+)",
        ticker,
    )

    if not m:
        raise ValueError(f"Unrecognized ticker format: {ticker}")

    series, yy, mon, dd, body = m.groups()
    teams_blob, sel = split_ncaaf_body_and_selection(body)

    month_num = datetime.strptime(mon, "%b").month
    year_full = 2000 + int(yy)
    game_date = f"{year_full:04d}-{month_num:02d}-{int(dd):02d}"

    away_code, home_code = split_ncaaf_teams_blob(teams_blob)

    away_name = NCAAF_TEAM_MAP.get(away_code, away_code)
    home_name = NCAAF_TEAM_MAP.get(home_code, home_code)
    sel_name = NCAAF_TEAM_MAP.get(sel, sel)

    matchup = None
    if away_code and home_code:
        matchup = f"{away_name} @ {home_name}"

    return {
        "series": series,
        "GameDate": game_date,
        "Away": away_code,
        "Home": home_code,
        "AwayName": away_name,
        "HomeName": home_name,
        "Selection": sel,
        "SelectionName": sel_name,
        "Matchup": matchup,
    }


def parse_kxnbagame_ticker(ticker: str):
    """
    Parse Kalshi NBA tickers like:
      KXNBAGAME-26JUN03NYKSAS-SAS

    Returns dict with:
      series
      GameDate (YYYY-MM-DD)
      Away, Home
      AwayName, HomeName
      Selection, SelectionName
      Matchup
    """
    m = re.fullmatch(
        r"(KXNBAGAME)-"
        r"(\d{2})"
        r"([A-Z]{3})"
        r"(\d{2})"
        r"([A-Z]+)"
        r"-([A-Z]{3})",
        ticker,
    )

    if not m:
        raise ValueError(f"Unrecognized ticker format: {ticker}")

    series, yy, mon, dd, teams_blob, sel = m.groups()

    month_num = datetime.strptime(mon, "%b").month
    year_full = 2000 + int(yy)
    game_date = f"{year_full:04d}-{month_num:02d}-{int(dd):02d}"

    away_code, home_code = split_nba_teams_blob(teams_blob)

    away_name = NBA_TEAM_MAP.get(away_code, away_code)
    home_name = NBA_TEAM_MAP.get(home_code, home_code)
    sel_name = NBA_TEAM_MAP.get(sel, sel)

    matchup = None
    if away_code and home_code:
        matchup = f"{away_name} @ {home_name}"

    return {
        "series": series,
        "GameDate": game_date,
        "Away": away_code,
        "Home": home_code,
        "AwayName": away_name,
        "HomeName": home_name,
        "Selection": sel,
        "SelectionName": sel_name,
        "Matchup": matchup,
    }


def parse_kxnhlgame_ticker(ticker: str):
    """
    Parse Kalshi NHL tickers like:
      KXNHLGAME-26JUN02VGKCAR
      KXNHLGAME-26JUN02VGKCAR-CAR

    Returns dict with:
      series
      GameDate (YYYY-MM-DD)
      Away, Home
      AwayName, HomeName
      Selection, SelectionName
      Matchup
    """
    ticker = ticker.upper()
    m = re.fullmatch(
        r"(KXNHLGAME)-"
        r"(\d{2})"
        r"([A-Z]{3})"
        r"(\d{2})"
        r"([A-Z]+)"
        r"(?:-([A-Z]{2,3}))?",
        ticker,
    )

    if not m:
        raise ValueError(f"Unrecognized ticker format: {ticker}")

    series, yy, mon, dd, teams_blob, sel = m.groups()

    month_num = datetime.strptime(mon, "%b").month
    year_full = 2000 + int(yy)
    game_date = f"{year_full:04d}-{month_num:02d}-{int(dd):02d}"

    away_code, home_code = split_nhl_teams_blob(teams_blob)

    away_name = NHL_TEAM_MAP.get(away_code, away_code)
    home_name = NHL_TEAM_MAP.get(home_code, home_code)
    sel_name = NHL_TEAM_MAP.get(sel, sel)

    matchup = None
    if away_code and home_code:
        matchup = f"{away_name} @ {home_name}"

    return {
        "series": series,
        "GameDate": game_date,
        "Away": away_code,
        "Home": home_code,
        "AwayName": away_name,
        "HomeName": home_name,
        "Selection": sel,
        "SelectionName": sel_name,
        "Matchup": matchup,
    }


def parse_kxmlbgame_ticker(ticker: str):
    """
    Parse Kalshi MLB tickers like:
      KXMLBGAME-26JUN021840DETTB
      KXMLBGAME-26JUN021840DETTB-TB
      KXMLBGAME-25OCT31LADTOR-TOR
      KXMLBGAME-25OCT14NLLSNLHS-NLLS
      KXMLBGAME-25SEP20CLEMING2-MIN

    Returns dict with:
      series
      GameDate (YYYY-MM-DD)
      GameTime (HH:MM from the ticker's four-digit time block, if present)
      Away, Home
      AwayName, HomeName
      Selection, SelectionName
      Matchup
    """
    ticker = ticker.upper()
    m = re.fullmatch(
        r"(KXMLBGAME)-"
        r"(\d{2})"
        r"([A-Z]{3})"
        r"(\d{2})"
        r"(\d{4})?"
        r"([A-Z]+\d*)"
        r"(?:-([A-Z]{2,4}))?",
        ticker,
    )

    if not m:
        raise ValueError(f"Unrecognized ticker format: {ticker}")

    series, yy, mon, dd, hhmm, teams_blob, sel = m.groups()

    month_num = datetime.strptime(mon, "%b").month
    year_full = 2000 + int(yy)
    game_date = f"{year_full:04d}-{month_num:02d}-{int(dd):02d}"
    game_time = f"{hhmm[:2]}:{hhmm[2:]}" if hhmm else None
    teams_blob = re.sub(r"G?\d+$", "", teams_blob)

    away_code, home_code = split_mlb_teams_blob(teams_blob)

    away_name = MLB_TEAM_MAP.get(away_code, away_code)
    home_name = MLB_TEAM_MAP.get(home_code, home_code)
    sel_name = MLB_TEAM_MAP.get(sel, sel)

    matchup = None
    if away_code and home_code:
        matchup = f"{away_name} @ {home_name}"

    return {
        "series": series,
        "GameDate": game_date,
        "GameTime": game_time,
        "Away": away_code,
        "Home": home_code,
        "AwayName": away_name,
        "HomeName": home_name,
        "Selection": sel,
        "SelectionName": sel_name,
        "Matchup": matchup,
    }


def ohlc_from_trades(
    trades_df: pd.DataFrame,
    freq: str = "1min",
    save_file: bool = False,
    save_path: str = r"E:\PredMktData\TradeExports"
) -> pd.DataFrame:
    """
    Aggregate raw trade data into OHLC + volume bars at a given frequency.

    The function automatically reads the ticker from the DataFrame, confirms
    all rows share the same ticker value, and raises an error if not.

    Parameters
    ----------
    trades_df : pd.DataFrame
        DataFrame of raw trades. Expected columns:
          - 'created_time' (datetime-like): timestamp of each trade
          - 'ticker' (str): market ticker (must be constant across all rows)
          - 'yes_price_dollars' (float, optional)
          - 'no_price_dollars' (float, optional)
          - 'count' (int, optional): number of contracts in the trade
    freq : str, default '1min'
        Resampling frequency ('1min', '5min', '1H', etc.)
    save_file : bool, default False
        If True, saves aggregated OHLCV data to a CSV.
    save_path : str, default 'E:\\PredMktData\\TradeExports'
        Directory for output files.

    Returns
    -------
    pd.DataFrame
        Columns: ['ticker','ts','open','high','low','close','volume']
    """

    # ------------------------------------------------------------------
    # 1. Handle empty input
    # ------------------------------------------------------------------
    if trades_df.empty:
        return pd.DataFrame(columns=["ticker", "ts", "open", "high", "low", "close", "volume"])

    df = trades_df.copy()

    # ------------------------------------------------------------------
    # 2. Validate and extract ticker
    # ------------------------------------------------------------------
    if "ticker" not in df.columns:
        raise ValueError("Input DataFrame must contain a 'ticker' column.")

    unique_tickers = df["ticker"].dropna().unique()
    if len(unique_tickers) != 1:
        raise ValueError(
            f"Expected exactly one unique ticker, but found {len(unique_tickers)}: {unique_tickers}"
        )

    ticker = unique_tickers[0]

    # ------------------------------------------------------------------
    # 3. Prepare data
    # ------------------------------------------------------------------
    if "count" not in df.columns:
        df["count"] = 1

    # Ensure datetime index for resampling
    df = df.set_index("created_time")

    # ------------------------------------------------------------------
    # 4. Determine price series
    # ------------------------------------------------------------------
    if "yes_price_dollars" in df.columns:
        price = df["yes_price_dollars"].copy()
    else:
        price = pd.Series(index=df.index, dtype="float64")

    if price.isna().all() and "no_price_dollars" in df.columns:
        price = 1 - df["no_price_dollars"]

    # ------------------------------------------------------------------
    # 5. Aggregate to OHLCV
    # ------------------------------------------------------------------
    agg = {
        "price": ["first", "max", "min", "last"],
        "count": "sum",
    }

    resampled = (
        pd.concat({"price": price, "count": df["count"]}, axis=1)
        .resample(freq)
        .agg(agg)
    )

    resampled.columns = ["open", "high", "low", "close", "volume"]
    resampled.index.name = "ts"
    resampled = resampled.reset_index()

    # ------------------------------------------------------------------
    # 6. Clean up empty intervals
    # ------------------------------------------------------------------
    resampled = resampled.dropna(subset=["open", "high", "low", "close"], how="all")

    # Add ticker column
    resampled["ticker"] = ticker
    resampled = resampled[["ticker", "ts", "open", "high", "low", "close", "volume"]]

    # ------------------------------------------------------------------
    # 7. Optional save to CSV
    # ------------------------------------------------------------------
    if save_file and not resampled.empty:
        os.makedirs(save_path, exist_ok=True)
        safe_ticker = str(ticker).replace("/", "-")
        filename = os.path.join(save_path, f"{safe_ticker}-Trades-{freq}.csv")
        resampled.to_csv(filename, index=False)
        print(f"Saved {len(resampled)} OHLC rows to {filename}")

    return resampled


def analyze_trade_interarrival(filepath: str, timestamp_col: str = "created_time") -> pd.DataFrame:
    """
    Read a trade file and compute interarrival times between successive records,
    preserving the file's original order.

    Parameters
    ----------
    filepath : str
        Path to the CSV file.
    timestamp_col : str, default 'created_time'
        Name of the timestamp column.

    Returns
    -------
    pandas.DataFrame
        DataFrame with columns:
        - 'ticker'
        - 'created_time'
        - 'interarrival'
    """
    # ✅ Use column *names*, not variables
    df = pd.read_csv(filepath, usecols=["ticker", timestamp_col])

    # Parse timestamps
    df[timestamp_col] = pd.to_datetime(df[timestamp_col], utc=True, errors="coerce")

    # Compute interarrival time
    df["interarrival"] = df[timestamp_col].diff()

    return df[["ticker", timestamp_col, "interarrival"]]

def fix_single_missing_timestamp(df: pd.DataFrame, col: str = "created_time") -> pd.DataFrame:
    mask = df[col].isna()
    idxs = np.where(mask.values)[0]
    if len(idxs) != 1:
        return df  # 0 or >1 NaT: leave as-is

    i = idxs[0]
    n = len(df)
    if n == 1:
        return df

    if 0 < i < n - 1:
        # interior: midpoint between neighbors
        t_prev = df[col].iloc[i - 1]
        t_next = df[col].iloc[i + 1]
        if pd.notna(t_prev) and pd.notna(t_next):
            df.loc[df.index[i], col] = t_prev + (t_next - t_prev) / 2
        return df

    # first row NaT
    if i == 0:
        t_next = df[col].iloc[1]
        if pd.notna(t_next):
            df.loc[df.index[0], col] = t_next - pd.Timedelta(microseconds=1)
        return df

    # last row NaT
    if i == n - 1:
        t_prev = df[col].iloc[n - 2]
        if pd.notna(t_prev):
            df.loc[df.index[n - 1], col] = t_prev + pd.Timedelta(microseconds=1)
        return df

    return df
