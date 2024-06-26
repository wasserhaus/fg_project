% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fg_project.R
\name{download_data}
\alias{download_data}
\title{Download data}
\usage{
download_data(x = "TSLA", start_date = "2011-01-03", end_date = Sys.Date())
}
\arguments{
\item{x}{string ticker symbol from yahoo finance}

\item{start_date}{string "YYYY-MM-DD" of starting date}

\item{end_date}{string "YYYY-MM-DD" of end date}
}
\value{
downloads data and returns dataframe with columns: Date, Fear&Greed numeric value, the Sentiment and info whether day closed postive/negative
}
\description{
Download data
}
\examples{
download_data("^GSPC")
download_data("AAPL", "2022-01-01", "2022-02-01")
}
