import plotly.graph_objects as go
import pandas as pd
import importlib.util
from pathlib import Path


_API_MODULE = None


def _get_api_module():
    global _API_MODULE
    if _API_MODULE is None:
        path = Path(__file__).with_name("Kalshi API Functions.py")
        spec = importlib.util.spec_from_file_location("kalshi_api_functions", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _API_MODULE = module
    return _API_MODULE


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
    book = _get_api_module().get_market_orderbook(ticker, depth=depth)

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


def plot_candlestick(df, title="Kalshi Market Candlestick Chart"):
    """
    Plot an interactive candlestick chart from OHLC data.
    Expects columns: ts, open, high, low, close
    """
    if df.empty:
        print("No data to plot.")
        return

    fig = go.Figure(
        data=[
            go.Candlestick(
                x=df["ts"],
                open=df["open"],
                high=df["high"],
                low=df["low"],
                close=df["close"],
                name="Price",
                increasing_line_color="green",
                decreasing_line_color="red",
            )
        ]
    )

    fig.update_layout(
        title=title,
        xaxis_title="Time (UTC)",
        yaxis_title="Yes Price ($)",
        xaxis_rangeslider_visible=False,
        template="plotly_white",
        height=600,
    )

    fig.show()
