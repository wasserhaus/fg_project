#' Title
#'
#' @param x numeric vector
#' @param weights numeric vector of weight with length of x
#' @param ...
#'
#' @return weighted sum
#' @export
#'
#' @examples
#' weight_sum(1:10)
weight_sum <- function(x, weights = rep(1, length(x)), ...){

  res <- sum(weights*x, ...)
  return(res)
}
