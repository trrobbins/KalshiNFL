import os
import pandas as pd


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


import pandas as pd

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

import requests
import pandas as pd
from datetime import datetime, timezone
import numpy as np

BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"

def _to_unix_utc(dt: datetime) -> int:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return int(dt.timestamp())



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
