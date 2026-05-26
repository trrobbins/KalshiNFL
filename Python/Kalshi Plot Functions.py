import plotly.graph_objects as go

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
