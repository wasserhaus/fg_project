



#' Download data
#'
#' @param x 
#' @param wish_date 
#'
#' @return
#' @export
#'
#' @examples
download_data <- function(x ="GC=F", wish_date =  Sys.Date()){
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
    
    ticker_prices <-tidyquant::tq_get(x,get = "stock.prices",from = "2011-01-03",to = wish_date) %>%
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
#' @param x 
#' @param wish_date 
#'
#' @return
#' @export
#'
#' @examples
visualize_data <- function(x ="GC=F", wish_date =  Sys.Date()){
  df_fg <- download_data(x, wish_date)
  fg_overview <- table(df_fg$Sentiment, df_fg$Close)
  
  fg_freq <- data.frame(table(df_fg$Sentiment))
  
  p1 <- ggplot(fg_freq, aes(x=Var1, y=Freq)) +
    geom_bar(stat = "identity")+
    xlab("Sentiment") +
    ylab("Count") +
    scale_x_discrete(limits=c("extreme fear", "fear", "neutral", "greed", "extreme greed"))+
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5)+
    theme_bw()
  print(p1)
  
  p2 <- ggplot(data = data.frame(fg_overview), aes(x=Var1,y=Freq, fill=Var2))+
    geom_bar(stat="identity",color = "black",position=position_dodge())+
    scale_x_discrete(limits=c("extreme fear", "fear", "neutral", "greed", "extreme greed"))+
    ylab("Frequency in Days") +
    xlab("Sentiment") +
    geom_text(aes(label=Freq), vjust=-0.3, size=3.5, position = position_dodge(0.9))+
    guides(fill=guide_legend(title="Outcome Day"))+
    theme_bw()
  print(p2)
  
  
  if("tidyquant" %in% installed.packages() == FALSE) {
    print("Please install the package tidyquant.")}
  else{
    ticker_prices <- tidyquant::tq_get(x,get = "stock.prices",from = "2011-01-03",to = wish_date) %>%
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
      theme_bw()
    print(p3)
    
    p4 <- ggplot()+
      geom_line(data = df_plot_full_log, aes(x= as.Date(Date), y= Value), color = 'blue', size = 0.5)+
      facet_grid(Type~., scales = "free")+
      xlab("Date") +
      geom_vline(xintercept =as.Date(subset(df_plot_full_log, Value <1.5 )$Date),color = 'red')+
      theme_bw()
    print(p4)}
}

#' Test data
#'
#' @param x 
#' @param wish_date 
#'
#' @return
#' @export
#'
#' @examples
test_data <- function(x ="GC=F", wish_date =  Sys.Date()){
  
  df_fg <- download_data(x, wish_date)
  
  df_fg$Close <- as.character(df_fg$Close)
  
  observed_indep_statistic <- df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::hypothesize(null = "independence") %>%
    infer::calculate(stat = "Chisq")
  print(observed_indep_statistic)
  
  
  null_dist_sim <- df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::hypothesize(null = "independence") %>%
    infer::generate(reps = 1000, type = "permute") %>%
    infer::calculate(stat = "Chisq")
  
  null_dist_theory <-  df_fg %>%
    infer::specify(Close~Sentiment) %>%
    infer::assume(distribution = "Chisq")
  
  null_dist_sim %>%
    infer::visualize(method = "both")+
    infer::shade_p_value(observed_indep_statistic,
                         direction = "greater")
  
  
  print(chisq.test(table(df_fg$Sentiment, df_fg$Close)))
}

#' Summary of data
#'
#' @param x 
#' @param wish_date 
#'
#' @return
#' @export
#'
#' @examples
num_summary <- function(x ="GC=F", wish_date =  Sys.Date()){
  if("tidyquant" %in% installed.packages() == FALSE) {
    print("Please install the package tidyquant.")}
  else{
    df_fg <- download_data(x, wish_date)
    ticker_prices <- tidyquant::tq_get(x,get = "stock.prices",from = "2011-01-03",to = wish_date) %>%
      select(date, open, close) %>%
      na.omit() %>%
      as.data.frame()
    print("Time horizont")
    print(paste("2011-01-03 to",as.Date(wish_date)))
    print("Total amount of observations (cleaned)")
    print(length(df_fg$Date))
    print("Removed observations")
    print(abs(length(ticker_prices$date)-length(df_fg$Date)))
    print("Summary of the ticker price data")
    print(summary(ticker_prices$close))
    print("Procentual change over given time")
    print(paste0(round((ticker_prices$close[length(ticker_prices$date)]/ticker_prices$close[1])*100,digits = 2),"%"))
    print("Frequency of each Sentiment over given time")
    print(table(df_fg$Sentiment))
    print("Frequency of negative(0) and positive(1) closed days over given time")
    print(table(df_fg$Close))
    print("Frequency of negative(0) and positive(1) closed days in regard of Sentiment over given time")
    print(table(df_fg$Sentiment,df_fg$Close))
  }
  
  
}