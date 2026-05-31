
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
- GetUnsavedTrades: retrieve recent trades for a ticker and optionally save them to CSV.
- LoadMissingNFLTrades: identify settled NFL games missing saved trade files and download them.
- _to_unix_utc: convert a datetime or ISO string to a Unix UTC timestamp.

"""

import requests
import pandas as pd
from datetime import datetime, timezone
import importlib.util
from pathlib import Path


BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"
_ANALYSIS_MODULE = None


def _get_analysis_module():
    global _ANALYSIS_MODULE
    if _ANALYSIS_MODULE is None:
        path = Path(__file__).with_name("Kalshi Analysis Functions.py")
        spec = importlib.util.spec_from_file_location("kalshi_analysis_functions", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _ANALYSIS_MODULE = module
    return _ANALYSIS_MODULE

def get_kalshi_series_df(series_ticker="KXNFLGAME", status="open", limit=200):
    """
    Generic function to retrieve markets from a Kalshi series.
    """

    params = {
        "series_ticker": series_ticker,
        "with_nested_markets": "true",
        "limit": str(limit)
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

def get_clean_nfl_games(status="open", limit=200):
    """
    Pull NFL markets for a given status, parse ticker metadata, and return an enriched DataFrame.
    """
    raw_df = get_nfl_games_df(status=status, limit=limit)

    if raw_df.empty:
        print(f"No NFL markets returned for status='{status}'.")
        return raw_df

    parsed_df = raw_df["Ticker"].apply(_get_analysis_module().parse_kxnflgame_ticker).apply(pd.Series)
    clean_df = pd.concat([raw_df, parsed_df], axis=1)

    # future tweak point:
    # clean_df["YesMid"] = (clean_df["YesBid"] + clean_df["YesAsk"]) / 2

    clean_df = clean_df.sort_values(
        ["GameDate", "Home", "Away", "Ticker"],
        na_position="last"
    ).reset_index(drop=True)

    return clean_df

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


def get_trades(ticker: str, start_dt: datetime, end_dt: datetime, limit: int = 1000) -> pd.DataFrame:
    params = {
        "ticker": ticker,
        "min_ts": _to_unix_utc(start_dt),
        "max_ts": _to_unix_utc(end_dt),
        "limit": limit,
    }

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
        return pd.DataFrame(
            columns=["created_time", "yes_price_dollars", "no_price_dollars", "count"]
        )

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
        df = _get_analysis_module().fix_single_missing_timestamp(df, col="created_time")

    # Numeric columns
    for col in ["yes_price_dollars", "no_price_dollars"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    if "count" in df.columns:
        df["count"] = pd.to_numeric(df["count"], errors="coerce")
    else:
        df["count"] = 1

    # ✅ Final: always sort ascending by time, stable for ties
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


def LoadMissingNFLTrades():
    """
    Load trades for all settled NFL games that don't yet have a saved trade file.

    Returns
    -------
    errors : pandas.DataFrame
        DataFrame with columns:
        - 'Ticker': the game ticker that failed
        - 'Error':  string representation of the exception

        If no errors occur, returns an empty DataFrame.
    """
    import os

    # 1. Get settled games
    settled_games = get_clean_nfl_games(status="settled")  # Games where contracts have settled
    df_settled = settled_games[["Ticker"]]

    # 2. Get list of already-downloaded trade files
    path = r"E:\PredMktData\TradeExports"
    trade_files = os.listdir(path)
    print("Existing trade files:", trade_files)

    df_trade = pd.DataFrame({"Filename": trade_files})
    df_trade["Ticker"] = df_trade["Filename"].str.replace("-Trades.csv", "", regex=False)

    # 3. Find which settled games do NOT yet have a trade file
    df_load = df_settled[~df_settled["Ticker"].isin(df_trade["Ticker"])]

    # 4. Loop through missing tickers and try to load trades
    error_log = []  # list of dicts: {"Ticker": ..., "Error": ...}

    for ticker in df_load["Ticker"]:
        print(f"\nProcessing {ticker}...")
        try:
            GetUnsavedTrades(ticker)
        except Exception as e:
            err_msg = str(e)
            print(f"❌ Error processing {ticker}: {err_msg}")
            error_log.append({"Ticker": ticker, "Error": err_msg})

    # 5. Return a DataFrame of errors (or an empty one if none)
    errors_df = pd.DataFrame(error_log, columns=["Ticker", "Error"])
    return errors_df


def _to_unix_utc(dt) -> int:
    if isinstance(dt, str):
        dt = datetime.fromisoformat(dt)

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)

    return int(dt.timestamp())
