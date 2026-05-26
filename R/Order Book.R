

## This script does some basic visualization on an imported order book


mybook <- read_csv("mybook.csv")
names (mybook)

library(tidyverse)
library(scales)

plot_market_impact <- function(book, book_action = "ASK") {
  
  Impact <- book %>%
    filter(Side == "YES", Action == book_action) %>%
    mutate(
      Price = as.numeric(Price),
      Qty = as.numeric(Qty)
    )
  
  if (book_action == "ASK") {
    Impact <- Impact %>% arrange(Price)
    graph_title <- "Market Impact: Buying YES Contracts"
    graph_subtitle <- "A market order walks up the ask side of the book"
  } else {
    Impact <- Impact %>% arrange(desc(Price))
    graph_title <- "Market Impact: Selling YES Contracts"
    graph_subtitle <- "A market order walks down the bid side of the book"
  }
  
  Impact <- Impact %>%
    mutate(
      CumQty = cumsum(Qty),
      CumCost = cumsum(Price * Qty),
      AvgExecutionPrice = CumCost / CumQty
    )
  
  ImpactPlot <- Impact %>%
    bind_rows(
      Impact %>%
        slice(1) %>%
        mutate(
          Qty = 0,
          CumQty = 0,
          CumCost = 0,
          AvgExecutionPrice = Price
        ),
      .
    ) %>%
    arrange(CumQty)
  
  ImpactPlot %>%
    ggplot(aes(x = CumQty)) +
    geom_step(aes(y = Price), linewidth = 1) +
    geom_line(aes(y = AvgExecutionPrice), linewidth = 1, linetype = "dashed") +
    scale_x_continuous(labels = scales::label_comma()) +
    scale_y_continuous(labels = scales::label_dollar(accuracy = 0.01)) +
    labs(
      title = graph_title,
      subtitle = graph_subtitle,
      x = "Market Order Quantity",
      y = "Price",
      caption = "Solid line = marginal execution price; dashed line = average execution price"
    ) +
    theme_minimal()
}

plot_market_impact(mybook, "BID")
plot_market_impact(mybook, "ASK")
