
#' Download data
#'
#' @param x string ticker symbol from yahoo finance
#' @param start_date string "YYYY-MM-DD" of starting date
#' @param end_date string "YYYY-MM-DD" of end date
#'
#' @return downloads data and returns dataframe with columns: Date, Fear&Greed numeric value, the Sentiment and info whether day closed postive/negative
#' @export
#'
#' @examples
#' download_data("^GSPC")
#' download_data("AAPL", "2022-01-01", "2022-02-01")
download_data <- function(x ="TSLA", start_date =  "2011-01-03", end_date = Sys.Date()){
  if("tidyquant" %in% installed.packages() == FALSE) {
    print("Please install the package tidyquant.")}
  else{
    #following section downloads fear and greed data and creates a dataframe
    url <- "https://production.dataviz.cnn.io/index/fearandgreed/graphdata/2020-09-18"

    raw_data <- httr::GET(url) %>%
      httr::content() %>%
      purrr::pluck("fear_and_greed_historical","data")

    df_fg <- as.data.frame(do.call(rbind, raw_data))
    colnames(df_fg)<- c("Date","Fear.Greed","Sentiment")
    df_fg$Fear.Greed <- floor(as.numeric(df_fg$Fear.Greed))
    df_fg$Date <- as.numeric(format(df_fg$Date, scientific = FALSE))/1000
    df_fg$Date <- as.factor(as.Date.POSIXct(df_fg$Date, origin = "1970-01-01"))

    raw_data_2<-read.csv("https://raw.githubusercontent.com/hackingthemarkets/sentiment-fear-and-greed/master/datasets/spy-put-call-fear-greed-vix.csv")%>%
      select(Date,Fear.Greed) %>%
      mutate(Sentiment = case_when(
        Fear.Greed < 25 ~ 'extreme fear',
        Fear.Greed < 45 ~ 'fear',
        Fear.Greed < 55 ~ 'neutral',
        Fear.Greed < 75 ~ 'greed',
        TRUE ~ 'extreme greed'))
    df_fg <- data.frame(rbind(raw_data_2, df_fg))
    df_fg$Sentiment <- as.character(df_fg$Sentiment)

    # following section downloads ticker price, convert to Up/Down and adds to dataframe

    ticker_prices <-tidyquant::tq_get(x,get = "stock.prices",from = start_date,to = end_date) %>%
      select(date, open, close) %>%
      na.omit() %>%
      as.data.frame()
    ticker_prices$date <- as.character(ticker_prices$date)
    ticker_binary <- as.integer(round(ticker_prices[3]-ticker_prices[2], digits = 2) > 0)
    df_ticker <- data.frame(Date = ticker_prices$date, Close =ticker_binary)

    df_fg <- merge(df_fg, df_ticker, by = "Date")
    return(df_fg)
  }
}


#' Visualize data
#'
#' @param x string ticker symbol from yahoo finance
#' @param start_date string "YYYY-MM-DD" of starting date
#' @param end_date string "YYYY-MM-DD" of end date
#'
#' @return visualization of data: barplot, price chart and fear&greed index
#' @export
#'
#' @examples
#' visualize_data("^GSPC")
#' visualize_data("AAPL", "2022-01-01", "2022-02-01")
visualize_data <- function(x ="TSLA", start_date =  "2011-01-03", end_date = Sys.Date()){
  df_fg <- download_data(x,start_date, end_date)

  fg_overview <- table(df_fg$Sentiment, df_fg$Close)
  fg_overview2 <- table(df_fg$Close, df_fg$Sentiment)

  fg_freq <- data.frame(table(df_fg$Sentiment))
  close_freq <- data.frame(table(df_fg$Close))

  if("tidyquant" %in% installed.packages() == FALSE) {
    print("Please install the package tidyquant.")}
  else{
    ticker_prices <- tidyquant::tq_get(x,get = "stock.prices",from = start_date,to = end_date) %>%
      select(date, open, close) %>%
      na.omit() %>%
      as.data.frame()


    df_plot1 <- data.frame(Date = as.Date(df_fg$Date), Value = df_fg$Fear.Greed, Type = "Fear and Greed" )
    df_plot2 <- data.frame(Date = ticker_prices$date, Value = ticker_prices$close, Type = "Price")
    df_plot_full <- dplyr::bind_rows(df_plot1,df_plot2)

    df_plot_full_log <-df_plot_full
    df_plot_full_log$Value <- log(df_plot_full_log$Value)
    df_plot_full_log$Value[which(!is.finite(df_plot_full_log$Value))] <-0


    p3 <- ggplot()+
      geom_line(data = df_plot_full, aes(x= as.Date(Date), y= Value),color='blue', size = 0.5)+
      facet_grid(Type~., scales = "free")+
      xlab("Date") +
      ggtitle(paste("Chart of Fear&Greed index and price of",x)) +
      theme_bw()
    print(p3)

    p4 <- ggplot()+
      geom_line(data = df_plot_full_log, aes(x= as.Date(Date), y= Value), color = 'blue', size = 0.5)+
      facet_grid(Type~., scales = "free")+
      xlab("Date") +
      ggtitle(paste("Logarithmic chart of Fear&Greed index and price of",x)) +
      #geom_vline(xintercept =as.Date(subset(df_plot_full_log, Value <1.5 )$Date),color = 'red')+
      theme_bw()
    print(p4)}


  p5<- ggplot(close_freq, aes(x=Var1, y=Freq)) +
    geom_bar(stat = "identity")+
    xlab("negative/positive closing") +
    ylab("Count") +
    ggtitle("Frequency of negative/positive closing") +
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5)+
    theme_bw()
  print(p5)

  plot_df2 <- data.frame(fg_overview2)
  plot_df2$Var2 = factor(plot_df2$Var2, levels = c("extreme fear", "fear", "neutral", "greed", "extreme greed"), ordered = TRUE)
  p6<-ggplot(data = plot_df2, aes(x=Var1,y=Freq, fill=Var2))+
    geom_bar(stat="identity",color = "black",position=position_dodge())+
    xlab("negative/positive closing") +
    ylab("Frequency in days") +
    ggtitle("Frequency of each sentiment given negative/positive closing") +
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5, position = position_dodge(0.9))+
    guides(fill=guide_legend(title="Sentiment"))+
    theme_bw()
  plot(p6)

  p1 <- ggplot(fg_freq, aes(x=Var1, y=Freq)) +
    geom_bar(stat = "identity")+
    xlab("Sentiment") +
    ylab("Count") +
    ggtitle("Frequency of each sentiment") +
    scale_x_discrete(limits=c("extreme fear", "fear", "neutral", "greed", "extreme greed"))+
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5)+
    theme_bw()
  print(p1)

  p2 <- ggplot(data = data.frame(fg_overview), aes(x=Var1,y=Freq, fill=Var2))+
    geom_bar(stat="identity",color = "black",position=position_dodge())+
    scale_x_discrete(limits=c("extreme fear", "fear", "neutral", "greed", "extreme greed"))+
    ylab("Frequency in Days") +
    xlab("Sentiment") +
    ggtitle("Frequency of negative/positive days given sentiment") +
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5, position = position_dodge(0.9))+
    guides(fill=guide_legend(title="Outcome Day"))+
    scale_fill_manual(values = c("firebrick2","limegreen"))+
    theme_bw()
  print(p2)

  df_fg$Close <- as.character(df_fg$Close)
  observed_indep_statistic <- df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::hypothesize(null = "independence") %>%
    infer::calculate(stat = "Chisq")

  null_dist_sim <- df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::hypothesize(null = "independence") %>%
    infer::generate(reps = 1000, type = "permute") %>%
    infer::calculate(stat = "Chisq")

  null_dist_theory <-  df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::assume(distribution = "Chisq")

  print(null_dist_sim %>%
          infer::visualize(method = "both")+
          infer::shade_p_value(observed_indep_statistic,
                               direction = "greater"))

}

#' Test data
#'
#' @param x string ticker symbol from yahoo finance
#' @param start_date string "YYYY-MM-DD" of starting date
#' @param end_date string "YYYY-MM-DD" of end date
#' @param visuals if TRUE, will show visualization of the test
#'
#' @return test data (Up/Down of a given stock/index/commodity and the Fear&Greed Index), tested with a chi-square test
#' @export
#'
#' @examples
#' test_data("^GSPC")
#' test_data("AAPL", "2022-01-01", "2022-02-01")
test_data <- function(x ="TSLA", start_date =  "2011-01-03", end_date = Sys.Date(), visuals = FALSE, ...){

  df_fg <- download_data(x, start_date, end_date)
  df_fg$Close <- as.character(df_fg$Close)

  if(visuals == TRUE){

    observed_indep_statistic <- df_fg %>%
      infer::specify(Close~Sentiment) %>%
      infer::hypothesize(null = "independence") %>%
      infer::calculate(stat = "Chisq")

    null_dist_sim <- df_fg %>%
      infer::specify(Close~Sentiment) %>%
      infer::hypothesize(null = "independence") %>%
      infer::generate(reps = 1000, type = "permute") %>%
      infer::calculate(stat = "Chisq")

    null_dist_theory <-  df_fg %>%
      infer::specify(Close~Sentiment) %>%
      infer::assume(distribution = "Chisq")

    print(null_dist_sim %>%
      infer::visualize(method = "both")+
      infer::shade_p_value(observed_indep_statistic,
                           direction = "greater"))
  }


  chi_test <- chisq.test(table(df_fg$Sentiment, df_fg$Close))
  print(chi_test)
  if(chi_test$p.value < 0.05){
    print(paste("According to the Chi-Square test, one get a p-value of", round(chi_test$p.value, digits=3),
                "which is less than the significance level of 0.05.
                One can reject the null-hypothesis, which means that those variables are stochastically dependent and there is
                a relationship between the Fear&Greed sentiment and the daily closings."))
  }
  else{
    print(paste("According to the Chi-Square test, one get a p-value of", round(chi_test$p.value, digits=3),
                "which is bigger than the significance level of 0.05.
                One cannot reject the null-hypothesis, which means that those variables are stochastically independent and there is
                no relationship between the Fear&Greed sentiment and the daily closings."))
  }
}

#' Summary of data
#'
#' @param x string ticker symbol from yahoo finance
#' @param start_date string "YYYY-MM-DD" of starting date
#' @param end_date string "YYYY-MM-DD" of end date
#'
#' @return numerical summary of the data
#' @export
#'
#' @examples
#' num_summary("^GSPC")
#' num_summary("AAPL", "2022-01-01", "2022-02-01")
num_summary <- function(x ="TSLA", start_date =  "2011-01-03", end_date = Sys.Date()){
  if("tidyquant" %in% installed.packages() == FALSE) {
    print("Please install the package tidyquant.")}
  else{
    df_fg <- download_data(x,start_date, end_date)
    ticker_prices <- tidyquant::tq_get(x,get = "stock.prices",from = start_date,to = end_date) %>%
      select(date, open, close) %>%
      na.omit() %>%
      as.data.frame()
    print("Time horizont")
    print(paste(as.Date(start_date),"to",as.Date(end_date)))
    print("Total amount of observations (cleaned)")
    print(length(df_fg$Date))
    print("Summary of the ticker price data")
    print(summary(ticker_prices$close))
    print("Procentual change over given time")
    print(paste0(round((ticker_prices$close[length(ticker_prices$date)]/ticker_prices$close[1])*100,digits = 2),"%"))
    print("Frequency of each Sentiment over given time")
    print(table(df_fg$Sentiment))
    print("Frequency of negative(0) and positive(1) closed days over given time")
    print(table(df_fg$Close))
    print("Frequency of negative(0) and positive(1) closed days in regard of sentiment over given time")
    print(table(df_fg$Sentiment,df_fg$Close))
  }


}
