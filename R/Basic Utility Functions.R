SavePlotToFile <- function (plot, fname){
  
  
  # This function will save a plot to a file
  
  # Define plot dimensions and resolution
  plot_width <- 10  # in inches
  plot_height <- 7  # in inches
  plot_dpi <- 300   # dots per inch for high resolution
  
  # Generate a filename
  filename <- str_c(fname,  ".png")
  
  # Save the plot
  ggsave(
    filename = filename,
    plot = plot,
    width = plot_width,
    height = plot_height,
    dpi = plot_dpi,
    bg = "white"  # Explicitly set the background color to white
  )
  
  message("Plot saved as: ", filename)
  
  
  
}


SaveGTTable <- function (gtTable,fname) {
  
  # This function will save a gt table to a png
  # file.  
  #
  # This is a work around for an issue with gtsave and chrome
  
  
  htmlfile <- 'Temp.html'
  pngfile <- str_c (fname, ".png")
  gtsave(gtTable, filename = htmlfile)
  
  
  webshot::webshot(
    url = htmlfile,
    file = pngfile ,
    vwidth = 1200,  # Virtual width in pixels
    vheight = 800,  # Virtual height in pixels
    zoom = 4        # Zoom level for higher resolution
  )
  
  return (pngfile)
  
}