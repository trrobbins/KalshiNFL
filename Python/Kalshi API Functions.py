
"""
This file contains a set of functions that interact with the Kalshi API to retrieve market data, analyze NFL game tickers, and manage trade data.
The functions are designed to be modular and reusable, allowing for easy integration into larger trading strategies or applications.
Each function includes error handling to ensure that any issues with API requests are properly managed.

Functions:
- split_teams_blob: split compact NFL team code blobs into away/home team codes.
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
- plot_market_impact: plot a market impact curve from an order book snapshot.
- get_trades: fetch historical trades for a ticker between two datetimes.
- parse_kxnflgame_ticker: parse an NFL market ticker into structured metadata.
- GetUnsavedTrades: retrieve recent trades for a ticker and optionally save them to CSV.
- LoadMissingNFLTrades: identify settled NFL games missing saved trade files and download them.
- _to_unix_utc: convert a datetime or ISO string to a Unix UTC timestamp.

"""

import requests
import pandas as pd
from datetime import datetime, timezone
import re


BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"

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

    parsed_df = raw_df["Ticker"].apply(parse_kxnflgame_ticker).apply(pd.Series)
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


def plot_market_impact(ticker: str, book_action: str = "ASK", side: str = "YES", depth: int = 10):
    """
    Get a Kalshi order book and plot the market impact curve.

    Parameters
    ----------
    ticker : str
        Kalshi market ticker.

    book_action : str
        "ASK" = buying contracts with a market order.
        "BID" = selling contracts with a market order.

    side : str
        "YES" or "NO". Defaults to "YES".

    depth : int
        Number of order book levels to retrieve.

    Returns
    -------
    fig, ax, impact
        Matplotlib figure, axes, and dataframe used for the plot.
    """

    import matplotlib.pyplot as plt
    from matplotlib.ticker import FuncFormatter

    book_action = book_action.upper()
    side = side.upper()

    if book_action not in ["ASK", "BID"]:
        raise ValueError('book_action must be either "ASK" or "BID"')

    if side not in ["YES", "NO"]:
        raise ValueError('side must be either "YES" or "NO"')

    # Get real-time order book
    book = get_market_orderbook(ticker, depth=depth)

    impact = (
        book
        .query("Side == @side and Action == @book_action")
        .copy()
    )

    if impact.empty:
        raise ValueError(f"No rows found for Side = {side}, Action = {book_action}")

    impact["Price"] = pd.to_numeric(impact["Price"])
    impact["Qty"] = pd.to_numeric(impact["Qty"])

    # Market buys consume asks from low to high.
    # Market sells consume bids from high to low.
    if book_action == "ASK":
        impact = impact.sort_values("Price", ascending=True)
    else:
        impact = impact.sort_values("Price", ascending=False)

    impact["CumQty"] = impact["Qty"].cumsum()
    impact["CumCost"] = (impact["Price"] * impact["Qty"]).cumsum()
    impact["AvgExecutionPrice"] = impact["CumCost"] / impact["CumQty"]

    # Use timestamp from book if available; otherwise use current UTC time
    if "ts_utc" in impact.columns:
        ts_utc = pd.to_datetime(impact["ts_utc"].iloc[0], utc=True)
    else:
        ts_utc = pd.Timestamp.now(tz="UTC")

    ts_et = ts_utc.tz_convert("America/New_York")
    ts_label = ts_et.strftime("%Y-%m-%d %I:%M:%S %p ET")

    # Step line: first price should apply from quantity 0 to first cumulative quantity
    step_x = [0] + impact["CumQty"].iloc[:-1].tolist() + [impact["CumQty"].iloc[-1]]
    step_y = impact["Price"].tolist() + [impact["Price"].iloc[-1]]

    # Average execution price line
    avg_x = [0] + impact["CumQty"].tolist()
    avg_y = [impact["Price"].iloc[0]] + impact["AvgExecutionPrice"].tolist()

    fig, ax = plt.subplots(figsize=(10, 6))

    ax.step(
        step_x,
        step_y,
        where="post",
        linewidth=2,
        label="Marginal execution price"
    )

    ax.plot(
        avg_x,
        avg_y,
        linestyle="dashed",
        linewidth=2,
        label="Average execution price"
    )

    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, pos: f"{x:,.0f}"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda y, pos: f"${y:,.2f}"))

    ax.set_title(
        f"{ticker} | {side} {book_action}\nOrder book snapshot: {ts_label}",
        fontsize=14,
        loc="left",
        pad=15
    )

    ax.set_xlabel("Market Order Quantity")
    ax.set_ylabel("Price")
    ax.legend()
    ax.grid(True, alpha=0.25)

    plt.tight_layout()

    return fig, ax, impact

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
        df = fix_single_missing_timestamp(df, col="created_time")

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