
"""
This file contains a set of functions that interact with the Kalshi API to retrieve market data, analyze NFL game tickers, and manage trade data.
The functions are designed to be modular and reusable, allowing for easy integration into larger trading strategies or applications.
Each function includes error handling to ensure that any issues with API requests are properly managed.

Functions:
- get_kalshi_series_df: retrieve all markets for a Kalshi series and return a sorted DataFrame.
- series_exists: check whether a Kalshi series exists via the API.
- get_markets_by_series: fetch raw market records for a series and normalize them into a DataFrame.
- get_nfl_games_df: wrapper to retrieve open NFL game markets.
- get_cfb_games_df: wrapper to retrieve open college football game markets.
- get_mlb_games_df: wrapper to retrieve open MLB game markets.
- get_nba_games_df: wrapper to retrieve open NBA game markets.
- get_clean_nfl_games: fetch and enrich NFL market data with parsed ticker metadata.
- get_market_quotes: fetch the latest quote for a single market ticker.
- get_market_orderbook: retrieve and normalize the order book for a market.
- get_trades: fetch historical trades for a ticker between two datetimes.
- get_historical_markets_by_series: fetch markets from Kalshi's historical market endpoint.
- get_historical_nfl_games_df: wrapper to retrieve historical NFL game markets.
- get_nfl_historical_games_df: backward-compatible alias for historical NFL game markets.
- get_historical_trades: fetch historical trades from Kalshi's historical trade endpoint.
- GetUnsavedTrades: retrieve recent trades for a ticker and optionally save them to CSV.
- LoadMissingNFLTrades: identify settled NFL games missing saved trade files and download them.
- _to_unix_utc: convert a datetime or ISO string to a Unix UTC timestamp.

"""

import requests
import pandas as pd
import os
from datetime import datetime, timezone
from kalshi_analysis import (
    fix_single_missing_timestamp,
    parse_kxnflgame_ticker,
    parse_kxncaafgame_ticker,
    parse_kxnbagame_ticker,
    parse_kxnhlgame_ticker,
    parse_kxmlbgame_ticker,
)


BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"

TRADE_COLUMNS = [
    "count",
    "created_time",
    "no_price",
    "no_price_dollars",
    "price",
    "taker_side",
    "ticker",
    "trade_id",
    "yes_price",
    "yes_price_dollars",
]

def get_kalshi_series_df(series_ticker="KXNFLGAME", status="open", limit=200):
    """
    Generic function to retrieve markets from a Kalshi series.

    The events endpoint treats limit as page size. Keep it within the endpoint's
    accepted range; cursor pagination below still retrieves every available page.
    """
    page_limit = min(int(limit), 200)

    params = {
        "series_ticker": series_ticker,
        "with_nested_markets": "true",
        "limit": str(page_limit)
    }
    if status is not None:
        params["status"] = status

    all_events = []
    cursor = None
    while True:
        if cursor:
            params["cursor"] = cursor

        r = requests.get(f"{BASE_URL}/events", params=params, timeout=30)
        r.raise_for_status()
        data = r.json()

        all_events.extend(data.get("events", []))
        cursor = data.get("cursor")
        if not cursor:
            break

    markets = []
    for e in all_events:
        for m in e.get("markets", []):
            markets.append({
                "Event":         e.get("title"),
                "Market":        m.get("title"),
                "Ticker":        m.get("ticker"),
                "CloseTime":     m.get("close_time"),
                "YesBid":        m.get("yes_bid_dollars"),
                "YesAsk":        m.get("yes_ask_dollars"),
                "NoBid":         m.get("no_bid_dollars"),
                "NoAsk":         m.get("no_ask_dollars"),
                "LastPrice":     m.get("last_price_dollars"),
                "OpenInterest":  m.get("open_interest"),
                "Volume24h":     m.get("volume_24h"),
                "Status":        m.get("status"),
            })

    df = pd.DataFrame(markets)

    if "CloseTime" in df.columns:
        df["CloseTime"] = pd.to_datetime(df["CloseTime"], utc=True, errors="coerce")
        df = df.sort_values("CloseTime").reset_index(drop=True)

    return df

def series_exists(series_ticker: str) -> bool:
    r = requests.get(f"{BASE_URL}/series/{series_ticker}", timeout=30)
    return r.status_code == 200

def get_markets_by_series(series_ticker: str, limit=500):
    """Fetch all markets for a Kalshi series and return them as a normalized DataFrame.

    Parameters
    ----------
    series_ticker : str
        The Kalshi series ticker to query (for example, "KXNFLGAME").
    limit : int, optional
        The maximum number of markets to request per API page, by default 500.

    Returns
    -------
    pandas.DataFrame
        Normalized market records for the requested series.
    """
    params = {"series_ticker": series_ticker, "limit": str(limit)}
    markets, cursor = [], None
    while True:
        if cursor: params["cursor"] = cursor
        r = requests.get(f"{BASE_URL}/markets", params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        markets.extend(data.get("markets", []))
        cursor = data.get("cursor")
        if not cursor: break
    return pd.json_normalize(markets)


def get_nfl_games_df(status="open", limit=200):
    """Wrapper for NFL markets specifically."""
    return get_kalshi_series_df(series_ticker="KXNFLGAME", status=status, limit=limit)

def get_cfb_games_df(status="open", limit=200):
    """Wrapper for College Football (NCAAF) game markets."""
    return get_kalshi_series_df(series_ticker="KXNCAAFGAME", status=status, limit=limit)


def get_mlb_games_df(status="open", limit=200):
    """Wrapper for Professional Baseball (MLB) game markets."""
    return get_kalshi_series_df(series_ticker="KXMLBGAME", status=status, limit=limit)


def get_nba_games_df(status="open", limit=200):
    """Wrapper for Professional Basketball (NBA) game markets."""
    return get_kalshi_series_df(series_ticker="KXNBAGAME", status=status, limit=limit)

def get_nhl_games_df(status="open", limit=200):
    """Wrapper for Professional Hockey (NHL) game markets."""
    return get_kalshi_series_df(series_ticker="KXNHLGAME", status=status, limit=limit)

def get_clean_nfl_games(status="open", limit=200):
    """
    Pull NFL markets for a given status, parse ticker metadata, and return an enriched DataFrame.
    """
    raw_df = get_nfl_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No NFL markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(parse_kxnflgame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    # future tweak point:
    # clean_df["YesMid"] = (clean_df["YesBid"] + clean_df["YesAsk"]) / 2

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df


def get_clean_cfb_games(status="open", limit=200):
    """
    Pull college football markets for a given status, parse ticker metadata,
    and return an enriched DataFrame.
    """
    raw_df = get_cfb_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No college football markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(parse_kxncaafgame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df


def get_clean_nba_games(status="open", limit=200):
    """
    Pull NBA markets for a given status, parse ticker metadata, and return an enriched DataFrame.
    """
    raw_df = get_nba_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No NBA markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(parse_kxnbagame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df


def get_clean_nhl_games(status="open", limit=200):
    """
    Pull NHL markets for a given status, parse ticker metadata, and return an enriched DataFrame.
    """
    raw_df = get_nhl_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No NHL markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(parse_kxnhlgame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df


def get_clean_mlb_games(status="open", limit=200):
    """
    Pull MLB markets for a given status, parse ticker metadata, and return an enriched DataFrame.
    """
    raw_df = get_mlb_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No MLB markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(parse_kxmlbgame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df


def _price_equals(series, target):
    """Compare price columns after numeric coercion."""
    return pd.to_numeric(series, errors="coerce").round(4).eq(target)


def _matchup_ticker(ticker):
    """Return the game-level ticker without the team selection suffix."""
    if pd.isna(ticker):
        return pd.NA

    parts = str(ticker).rsplit("-", 1)
    if len(parts) == 2:
        return parts[0]
    return str(ticker)


def _select_game_team(group, candidate_mask, role):
    """
    Pick one team selection from a game-level group.

    Settled markets can leave both rows with boundary bid/ask values, so use
    LastPrice as a tiebreaker when the requested boundary rule is not unique.
    """
    candidates = group.loc[candidate_mask & group["Selection"].notna()].copy()

    if candidates.empty:
        return pd.NA

    unique_selections = candidates["Selection"].dropna().unique()
    if len(unique_selections) == 1:
        return unique_selections[0]

    if "LastPrice" not in candidates.columns:
        raise ValueError(
            f"Could not determine {role}; multiple selections match and LastPrice is unavailable."
        )

    candidates["_LastPrice"] = pd.to_numeric(candidates["LastPrice"], errors="coerce")
    ascending = role == "loser"
    candidates = candidates.sort_values("_LastPrice", ascending=ascending)

    return candidates.iloc[0]["Selection"]


def build_game_winner_df(games_df):
    """
    Convert team-level Kalshi game markets into one winner/loser row per game.
    """
    output_columns = ["Event", "Ticker", "GameDate", "winner", "loser"]
    if games_df.empty:
        return pd.DataFrame(columns=output_columns)

    required_columns = {"Event", "Ticker", "GameDate", "Away", "Home", "Selection", "YesAsk", "YesBid"}
    missing_columns = required_columns - set(games_df.columns)
    if missing_columns:
        missing = ", ".join(sorted(missing_columns))
        raise ValueError(f"Input games DataFrame is missing required columns: {missing}")

    df = games_df.copy()
    df["GameDate"] = pd.to_datetime(df["GameDate"], errors="coerce").dt.normalize()
    df["MatchupTicker"] = df["Ticker"].apply(_matchup_ticker)

    group_columns = ["MatchupTicker", "GameDate", "Away", "Home"]
    if "GameTime" in df.columns:
        group_columns.append("GameTime")

    rows = []
    for _, group in df.groupby(group_columns, dropna=False, sort=True):
        winner = _select_game_team(group, _price_equals(group["YesAsk"], 1), "winner")
        loser = _select_game_team(group, _price_equals(group["YesBid"], 0), "loser")

        rows.append({
            "Event": group["Event"].dropna().iloc[0] if group["Event"].notna().any() else pd.NA,
            "Ticker": group["MatchupTicker"].dropna().iloc[0] if group["MatchupTicker"].notna().any() else pd.NA,
            "GameDate": group["GameDate"].dropna().iloc[0] if group["GameDate"].notna().any() else pd.NaT,
            "winner": winner,
            "loser": loser,
        })

    result = pd.DataFrame(rows, columns=output_columns).sort_values(
        ["GameDate", "Event"],
        na_position="last",
    ).reset_index(drop=True)

    result["GameDate"] = result["GameDate"].dt.date
    return result


def get_game_winners(get_clean_games, limit=200):
    """
    Generic wrapper for settled Kalshi game winner results.
    """
    games = get_clean_games(status="settled", limit=limit)
    return build_game_winner_df(games)


def get_nfl_winner(limit=200):
    """
    Return settled NFL game winners in one-row-per-game format.
    """
    return get_game_winners(get_clean_nfl_games, limit=limit)


def get_cfb_winner(limit=200):
    """
    Return settled college football game winners in one-row-per-game format.
    """
    return get_game_winners(get_clean_cfb_games, limit=limit)


def get_nba_winner(limit=200):
    """
    Return settled NBA game winners in one-row-per-game format.
    """
    return get_game_winners(get_clean_nba_games, limit=limit)


def get_nhl_winner(limit=200):
    """
    Return settled NHL game winners in one-row-per-game format.
    """
    return get_game_winners(get_clean_nhl_games, limit=limit)


def get_mlb_winner(limit=200):
    """
    Return settled MLB game winners in one-row-per-game format.
    """
    return get_game_winners(get_clean_mlb_games, limit=limit)


def get_market_quotes(ticker: str) -> dict:
    """
    Fetch the latest quote for a single market.
    Returns dict with Yes/No bid/ask and last price.
    """
    r = requests.get(f"{BASE_URL}/markets/{ticker}", timeout=30)
    r.raise_for_status()
    m = r.json().get("market", {})

    data =  {
        "ts_utc": datetime.now(timezone.utc),
        "Ticker": ticker,
        "YesBid": m.get("yes_bid_dollars"),
        "YesAsk": m.get("yes_ask_dollars"),
        "NoBid":  m.get("no_bid_dollars"),
        "NoAsk":  m.get("no_ask_dollars"),
        "LastPrice": m.get("last_price_dollars"),
        "Status": m.get("status"),
    }

    return pd.DataFrame([data])



def get_market_orderbook(ticker: str, depth: int = 10) -> pd.DataFrame:
    params = {"depth": depth}
    r = requests.get(
        f"{BASE_URL}/markets/{ticker}/orderbook", 
        params=params, 
        timeout=30
    )
    r.raise_for_status()

    data = r.json()

    # Current Kalshi API uses orderbook_fp
    ob = data.get("orderbook_fp", {})

    yes_bids = ob.get("yes_dollars") or []
    no_bids  = ob.get("no_dollars")  or []

    def implied_asks_from_bids(bids):
        rows = []
        for px_str, qty in bids:
            px = 1.0 - float(px_str)
            rows.append((round(px, 4), qty))
        return rows

    yes_asks = implied_asks_from_bids(no_bids)
    no_asks  = implied_asks_from_bids(yes_bids)

    ts = datetime.now(timezone.utc)

    rows = []

    def add_rows(levels, side, action):
        for price, qty in levels:
            rows.append({
                "ts_utc": ts,
                "Ticker": ticker,
                "Side": side,
                "Action": action,
                "Price": float(price),
                "Qty": int(float(qty)),
            })

    add_rows([(float(p), q) for p, q in yes_bids], "YES", "BID")
    add_rows(yes_asks, "YES", "ASK")
    add_rows([(float(p), q) for p, q in no_bids],  "NO",  "BID")
    add_rows(no_asks,  "NO",  "ASK")

    return pd.DataFrame(rows)


def get_trades(
    ticker: str,
    start_dt: datetime = None,
    end_dt: datetime = None,
    limit: int = 1000
) -> pd.DataFrame:
    """
    Fetch trades for a market ticker, optionally bounded by start/end datetimes.

    If start_dt or end_dt is omitted, that timestamp bound is not sent to Kalshi.
    """
    params = {
        "ticker": ticker,
        "limit": limit,
    }

    if start_dt is not None:
        params["min_ts"] = _to_unix_utc(start_dt)

    if end_dt is not None:
        params["max_ts"] = _to_unix_utc(end_dt)

    trades = []
    cursor = None
    while True:
        if cursor:
            params["cursor"] = cursor
        r = requests.get(f"{BASE_URL}/markets/trades", params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        trades.extend(data.get("trades", []))
        cursor = data.get("cursor")
        if not cursor:
            break

    if not trades:
        return pd.DataFrame(columns=TRADE_COLUMNS)

    df = pd.json_normalize(trades)

    # Robust timestamp parsing
    df["created_time"] = pd.to_datetime(
        df["created_time"],
        utc=True,
        errors="coerce",
    )

    # Fix the single NaT, if there is exactly one
    if df["created_time"].isna().any():
        print(f"⚠️ {df['created_time'].isna().sum()} unparseable timestamps in trades for {ticker}")
        df = fix_single_missing_timestamp(df, col="created_time")

    # Numeric columns
    for col in [
        "yes_price_dollars",
        "no_price_dollars",
        "yes_price",
        "no_price",
        "price",
        "count_fp",
    ]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    if "count" in df.columns:
        df["count"] = pd.to_numeric(df["count"], errors="coerce")
    else:
        df["count"] = 1

    if "count_fp" in df.columns:
        df["count"] = df["count_fp"].fillna(df["count"])

    if "yes_price_dollars" in df.columns:
        yes_price = (df["yes_price_dollars"] * 100).round()
        if "yes_price" in df.columns:
            df["yes_price"] = df["yes_price"].fillna(yes_price)
        else:
            df["yes_price"] = yes_price

    if "no_price_dollars" in df.columns:
        no_price = (df["no_price_dollars"] * 100).round()
        if "no_price" in df.columns:
            df["no_price"] = df["no_price"].fillna(no_price)
        else:
            df["no_price"] = no_price

    if "price" not in df.columns:
        df["price"] = pd.NA

    if "taker_side" in df.columns:
        yes_trades = df["taker_side"].str.lower().eq("yes")
        no_trades = df["taker_side"].str.lower().eq("no")
        if "yes_price_dollars" in df.columns:
            df.loc[yes_trades, "price"] = df.loc[yes_trades, "price"].fillna(
                df.loc[yes_trades, "yes_price_dollars"]
            )
        if "no_price_dollars" in df.columns:
            df.loc[no_trades, "price"] = df.loc[no_trades, "price"].fillna(
                df.loc[no_trades, "no_price_dollars"]
            )

    # ✅ Final: always sort ascending by time, stable for ties
    df = df.sort_values("created_time", kind="mergesort").reset_index(drop=True)

    for col in TRADE_COLUMNS:
        if col not in df.columns:
            df[col] = pd.NA

    df = df[TRADE_COLUMNS]
    return df


def get_historical_markets_by_series(series_ticker: str, limit: int = 500) -> pd.DataFrame:
    """
    Fetch markets for a Kalshi series from the historical markets endpoint.

    This is useful for older or settled markets that are no longer available from
    the standard active-market endpoints.
    """
    params = {
        "series_ticker": series_ticker,
        "limit": str(limit),
    }

    markets = []
    cursor = None
    while True:
        if cursor:
            params["cursor"] = cursor

        r = requests.get(f"{BASE_URL}/historical/markets", params=params, timeout=30)
        r.raise_for_status()
        data = r.json()

        markets.extend(data.get("markets", []))
        cursor = data.get("cursor")
        if not cursor:
            break

    return pd.json_normalize(markets)


def get_historical_nfl_games_df(limit: int = 500) -> pd.DataFrame:
    """Wrapper for historical NFL game markets."""
    return get_historical_markets_by_series(series_ticker="KXNFLGAME", limit=limit)


def get_historical_cfb_games_df(limit: int = 500) -> pd.DataFrame:
    """Wrapper for historical college football game markets."""
    return get_historical_markets_by_series(series_ticker="KXNCAAFGAME", limit=limit)


def get_nfl_historical_games_df(limit: int = 500) -> pd.DataFrame:
    """Backward-compatible alias for get_historical_nfl_games_df."""
    return get_historical_nfl_games_df(limit=limit)


def get_historical_trades(
    ticker: str,
    min_ts=None,
    max_ts=None,
    limit: int = 1000
) -> pd.DataFrame:
    """
    Fetch historical trades for a market ticker.

    min_ts and max_ts may be Unix timestamps, datetime objects, or ISO datetime
    strings. If omitted, Kalshi returns the endpoint's default time window.
    """
    params = {
        "ticker": ticker,
        "limit": str(limit),
    }

    if min_ts is not None:
        params["min_ts"] = _optional_unix_utc(min_ts)

    if max_ts is not None:
        params["max_ts"] = _optional_unix_utc(max_ts)

    trades = []
    cursor = None
    while True:
        if cursor:
            params["cursor"] = cursor

        r = requests.get(f"{BASE_URL}/historical/trades", params=params, timeout=30)
        r.raise_for_status()
        data = r.json()

        trades.extend(data.get("trades", []))
        cursor = data.get("cursor")
        if not cursor:
            break

    if not trades:
        return pd.DataFrame()

    df = pd.json_normalize(trades)

    if "created_time" in df.columns:
        df["created_time"] = pd.to_datetime(df["created_time"], utc=True, errors="coerce")
        df = df.sort_values("created_time", kind="mergesort").reset_index(drop=True)

    return df


def GetUnsavedTrades(
    tkr: str,
    save_file: bool = True,
    save_path: str = r"E:\PredMktData\TradeExports"
):
    """
    Retrieve and optionally save recent trades for a given ticker.

    Parameters
    ----------
    tkr : str
        The Kalshi market ticker (e.g., 'KXNFLGAME-25SEP07MIAIND-MIA').
    save_file : bool, default=True
        Whether to save the results as a CSV file.
    save_path : str, default='E:\\PredMktData\\TradeExports'
        Folder where the CSV should be saved.

    Returns
    -------
    pandas.DataFrame
        A DataFrame of raw trades retrieved via get_trades().
    """
    import os

    # --- Time window: last 180 days ---
    end = pd.Timestamp.now(tz="UTC")
    start = end - pd.Timedelta(days=180)

    # --- Get raw trades ---
    tr = get_trades(tkr, start, end)

    # --- Optionally save ---
    if save_file and not tr.empty:
        os.makedirs(save_path, exist_ok=True)
        safe_tkr = tkr.replace("/", "-")
        filename = os.path.join(save_path, f"{safe_tkr}-Trades.csv")
        tr.to_csv(filename, index=False)
        print(f"Saved {len(tr)} rows to {filename}")

    return tr


def _nfl_season_from_game_date(game_date) -> int:
    """Return the NFL season for a game date."""
    game_date = pd.to_datetime(game_date)
    return game_date.year if game_date.month >= 8 else game_date.year - 1


def _nba_season_from_game_date(game_date) -> int:
    """Return the NBA season for a game date."""
    game_date = pd.to_datetime(game_date)
    return game_date.year if game_date.month >= 10 else game_date.year - 1


def _nhl_season_from_game_date(game_date) -> int:
    """Return the NHL season for a game date."""
    game_date = pd.to_datetime(game_date)
    return game_date.year if game_date.month >= 10 else game_date.year - 1


def _calendar_year_season_from_game_date(game_date) -> int:
    """Return the calendar-year season for sports played within one year."""
    game_date = pd.to_datetime(game_date)
    return game_date.year


SPORT_TRADE_CONFIG = {
    "NFL": {
        "get_clean_games": get_clean_nfl_games,
        "season_from_date": _nfl_season_from_game_date,
    },
    "CFB": {
        "get_clean_games": get_clean_cfb_games,
        "season_from_date": _nfl_season_from_game_date,
    },
    "NCAAF": {
        "get_clean_games": get_clean_cfb_games,
        "season_from_date": _nfl_season_from_game_date,
    },
    "NBA": {
        "get_clean_games": get_clean_nba_games,
        "season_from_date": _nba_season_from_game_date,
    },
    "NHL": {
        "get_clean_games": get_clean_nhl_games,
        "season_from_date": _nhl_season_from_game_date,
    },
    "MLB": {
        "get_clean_games": get_clean_mlb_games,
        "season_from_date": _calendar_year_season_from_game_date,
    },
}


def LoadMissingTrades(
    sport: str,
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports",
    status: str = "settled",
    limit: int = 200
):
    """
    Load trades for games in a sport/season that lack saved trade files.

    Files are stored under a per-season subdirectory:
    ``{base_path}\\{sport}{season}``, for example
    ``E:\\PredMktData\\TradeExports\\NBA2025``.
    """
    sport = sport.upper()
    if sport not in SPORT_TRADE_CONFIG:
        valid_sports = ", ".join(sorted(SPORT_TRADE_CONFIG))
        raise ValueError(f"Unsupported sport '{sport}'. Valid sports: {valid_sports}")

    config = SPORT_TRADE_CONFIG[sport]
    error_columns = ["Ticker", "Error"]
    trade_path = os.path.join(base_path, f"{sport}{season}")
    os.makedirs(trade_path, exist_ok=True)

    games = config["get_clean_games"](status=status, limit=limit)
    if games.empty:
        print(f"No {status} {sport} games returned for season {season}.")
        return pd.DataFrame(columns=error_columns)

    games = games.copy()
    games["Season"] = games["GameDate"].apply(config["season_from_date"])
    df_season = games.loc[
        games["Season"] == season,
        ["Ticker"]
    ]

    if df_season.empty:
        print(f"No {status} {sport} games found for season {season}.")
        return pd.DataFrame(columns=error_columns)

    df_trade = GetTradeFiles(trade_path)
    df_load = df_season[~df_season["Ticker"].isin(df_trade["Ticker"])]

    if df_load.empty:
        print(f"No missing {sport} trade files for season {season}.")
        return pd.DataFrame(columns=error_columns)

    error_log = []
    for ticker in df_load["Ticker"]:
        print(f"\nProcessing {ticker}...")
        try:
            GetUnsavedTrades(ticker, save_path=trade_path)
        except Exception as e:
            err_msg = str(e)
            print(f"Error processing {ticker}: {err_msg}")
            error_log.append({"Ticker": ticker, "Error": err_msg})

    return pd.DataFrame(error_log, columns=error_columns)


def LoadMissingNFLTrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """
    Load trades for settled NFL games in a season that lack saved trade files.

    Files are stored under a per-season subdirectory:
    ``{base_path}\\NFL{season}``, for example
    ``E:\\PredMktData\\TradeExports\\NFL2025``.

    Returns
    -------
    errors : pandas.DataFrame
        DataFrame with columns:
        - 'Ticker': the game ticker that failed
        - 'Error':  string representation of the exception

        If no errors occur, returns an empty DataFrame.
    """
    return LoadMissingTrades("NFL", season, base_path=base_path)


def LoadMissingCFBTrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """Load missing college football trade files for a season."""
    return LoadMissingTrades("CFB", season, base_path=base_path)


def LoadMissingNCAAFTrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """Load missing college football trade files for a season."""
    return LoadMissingTrades("NCAAF", season, base_path=base_path)


def LoadMissingNBATrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """Load missing NBA trade files for a season."""
    return LoadMissingTrades("NBA", season, base_path=base_path)


def LoadMissingNHLTrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """Load missing NHL trade files for a season."""
    return LoadMissingTrades("NHL", season, base_path=base_path)


def LoadMissingMLBTrades(
    season: int,
    base_path: str = r"E:\PredMktData\TradeExports"
):
    """Load missing MLB trade files for a season."""
    return LoadMissingTrades("MLB", season, base_path=base_path)


def _to_unix_utc(dt) -> int:
    if isinstance(dt, str):
        dt = datetime.fromisoformat(dt)

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)

    return int(dt.timestamp())


def _optional_unix_utc(value) -> int:
    """Convert datetimes/ISO strings to Unix UTC, while preserving timestamp inputs."""
    if isinstance(value, (int, float)):
        return int(value)

    return _to_unix_utc(value)

def GetTradeFiles(trade_path: str = r"E:\PredMktData\TradeExports") -> pd.DataFrame:
    """
    Retrieve a list of all trade CSV files from a specified directory
    and return them as a pandas DataFrame.

    The function identifies files ending with '-Trades.csv', constructs
    their full file paths, and derives a corresponding ticker name by
    removing the '-Trades.csv' suffix.

    Parameters
    ----------
    trade_path : str, optional
        The directory containing trade export files.
        Defaults to 'E:\\PredMktData\\TradeExports'.

    Returns
    -------
    pandas.DataFrame
        A DataFrame with the following columns:
        - 'Filename' : the CSV filename (e.g., 'KXNFLGAME-25SEP04DALPHI-PHI-Trades.csv')
        - 'FullPath' : the full path to the file
        - 'Ticker'   : the ticker extracted from the filename
                       (e.g., 'KXNFLGAME-25SEP04DALPHI-PHI')

    Raises
    ------
    FileNotFoundError
        If the specified trade_path directory does not exist.

    Examples
    --------
    >>> df_trade = GetTradeFiles()
    >>> print(df_trade.head())

    >>> df_custom = GetTradeFiles(trade_path=r"D:\\MyProject\\Data\\Trades")
    >>> print(len(df_custom))
    """

    # ------------------------------------------------------------------
    # 1. Validate directory existence
    # ------------------------------------------------------------------
    if not os.path.exists(trade_path):
        raise FileNotFoundError(f"The directory does not exist: {trade_path}")

    # ------------------------------------------------------------------
    # 2. Collect all filenames ending with '-Trades.csv'
    # ------------------------------------------------------------------
    trade_files = [
        f for f in os.listdir(trade_path)
        if f.endswith("-Trades.csv")
    ]

    if not trade_files:
        print(f"Found 0 trade files in {trade_path}")
        return pd.DataFrame(columns=["Filename", "FullPath", "Ticker"])

    # ------------------------------------------------------------------
    # 3. Construct DataFrame with filenames and paths
    # ------------------------------------------------------------------
    df_trade = pd.DataFrame(
        {
            "Filename": trade_files,
            "FullPath": [os.path.join(trade_path, f) for f in trade_files],
        },
        columns=["Filename", "FullPath"],
    )

    # ------------------------------------------------------------------
    # 4. Derive ticker name from filename
    # ------------------------------------------------------------------
    df_trade["Ticker"] = df_trade["Filename"].str.replace("-Trades.csv", "", regex=False)

    # ------------------------------------------------------------------
    # 5. Provide summary and return
    # ------------------------------------------------------------------
    print(f"Found {len(df_trade)} trade files in {trade_path}")
    return df_trade


