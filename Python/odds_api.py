import os

import pandas as pd
import requests


ODDS_API_BASE_URL = "https://api.the-odds-api.com/v4/sports"


def _get_odds_api_key(api_key: str | None = None) -> str:
    key = api_key or os.getenv("THE_ODDS_API_KEY") or os.getenv("ODDS_API_KEY")
    if not key:
        raise ValueError(
            "Odds API key is required. Pass api_key=... or set THE_ODDS_API_KEY."
        )
    return key


def _flatten_odds_json(odds_json) -> pd.DataFrame:
    rows = []

    for game in odds_json:
        game_meta = {
            "game_id": game.get("id"),
            "sport_key": game.get("sport_key"),
            "sport_title": game.get("sport_title"),
            "commence_time": game.get("commence_time"),
            "home_team": game.get("home_team"),
            "away_team": game.get("away_team"),
        }

        for bookmaker in game.get("bookmakers", []):
            bookmaker_meta = {
                "bookmaker_key": bookmaker.get("key"),
                "bookmaker_title": bookmaker.get("title"),
                "bookmaker_last_update": bookmaker.get("last_update"),
            }

            for market in bookmaker.get("markets", []):
                market_meta = {
                    "market_key": market.get("key"),
                    "market_last_update": market.get("last_update"),
                }

                for outcome in market.get("outcomes", []):
                    rows.append({**game_meta, **bookmaker_meta, **market_meta, **outcome})

    return pd.DataFrame(rows)


def _header_int(headers, name: str):
    value = headers.get(name)
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return value


def get_quota(df: pd.DataFrame) -> dict:
    """
    Return Odds API quota fields attached to a DataFrame by get_odds_df().
    """
    return {
        "requests_remaining": df.attrs.get("x_requests_remaining"),
        "requests_used": df.attrs.get("x_requests_used"),
    }


def get_odds_df(
    sport: str,
    region: str = "us",
    markets: str = "h2h",
    odds_format: str = "decimal",
    api_key: str | None = None,
    date_format: str = "iso",
    show_quota: bool = True,
) -> pd.DataFrame:
    """
    Fetch live/upcoming odds from The Odds API and return a flattened DataFrame.

    Parameters
    ----------
    sport : str
        The Odds API sport key, for example "americanfootball_nfl" or
        "americanfootball_ncaaf".
    region : str, default "us"
        Bookmaker region. Multiple regions can be comma-delimited.
    markets : str, default "h2h"
        Market keys such as "h2h", "spreads", "totals", or a comma-delimited list.
    odds_format : str, default "decimal"
        Odds format, usually "decimal" or "american".
    api_key : str, optional
        API key. If omitted, THE_ODDS_API_KEY or ODDS_API_KEY is used.
    date_format : str, default "iso"
        Date format returned by the API, usually "iso" or "unix".
    show_quota : bool, default True
        Print request quota information returned by the API.
    """
    params = {
        "api_key": _get_odds_api_key(api_key),
        "regions": region,
        "markets": markets,
        "oddsFormat": odds_format,
        "dateFormat": date_format,
    }

    response = requests.get(
        f"{ODDS_API_BASE_URL}/{sport}/odds",
        params=params,
        timeout=30,
    )

    if response.status_code != 200:
        raise RuntimeError(
            f"Failed to get odds: status_code={response.status_code}, body={response.text}"
        )

    df = _flatten_odds_json(response.json())
    if "commence_time" in df.columns:
        df["commence_time"] = pd.to_datetime(df["commence_time"], utc=True, errors="coerce")
    if "bookmaker_last_update" in df.columns:
        df["bookmaker_last_update"] = pd.to_datetime(
            df["bookmaker_last_update"], utc=True, errors="coerce"
        )
    if "market_last_update" in df.columns:
        df["market_last_update"] = pd.to_datetime(
            df["market_last_update"], utc=True, errors="coerce"
        )

    df.attrs["x_requests_remaining"] = _header_int(
        response.headers, "x-requests-remaining"
    )
    df.attrs["x_requests_used"] = _header_int(response.headers, "x-requests-used")

    if show_quota:
        quota = get_quota(df)
        print(
            "Odds API quota: "
            f"{quota['requests_remaining']} requests remaining, "
            f"{quota['requests_used']} requests used"
        )

    return df
