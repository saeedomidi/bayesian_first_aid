#' Title title title
#' 
#' Descritions description description
#' 
#' Details details details
#' 
#' @param x 
#' @param ... 
#' @param y 
#' @param alternative 
#' @param method 
#' @param exact 
#' @param conf.level 
#' @param continuity 
#' @param n.iter
#' @param progress.bar The type of progress bar. Possible values are "text",
#'   "gui", and "none".
#' @param formula 
#' @param data 
#' @param subset 
#' @param na.action 
#' 
#' @return A list of class \code{bayes_cor_test} that contains information about
#'   the analysis. It can be further inspected using the functions
#'   \code{summary}, \code{plot}, \code{\link{diagnostics}} and 
#'   \code{\link{model.code}}.
#' @export
#' @rdname bayes.cor.test
bayes.cor.test <- function(x, ...) {
  UseMethod("bayes.cor.test")
}

cor_model_string <- "model {
  for(i in 1:n) {
    xy[i,1:2] ~ dmt(mu[], prec[ , ], nu) 
  }

  ## priors for elements of precision matrix
  prec[1:2,1:2] <- inverse(cov[,])
  
  cov[1,1] <- sigma[1] * sigma[1]
  cov[1,2] <- sigma[1] * sigma[2] * rho
  cov[2,1] <- sigma[1] * sigma[2] * rho
  cov[2,2] <- sigma[2] * sigma[2]
  
  sigma[1] ~ dunif(0, 1000) 
  sigma[2] ~ dunif(0, 1000)
  tau[1] <- 1 / pow(sigma[1], 2)
  tau[2] <- 1 / pow(sigma[2], 2)
  rho ~ dunif(-1, 1)

  mu[1] ~ dnorm(0, 0.0001)
  mu[2] ~ dnorm(0, 0.0001)

  nu <- nuMinusOne+1
  nuMinusOne ~ dexp(1/29)
}"

jags_cor_test <- function(x, y, n.adapt= 1000, n.chains=3, n.update = 1000, n.iter=5000, thin=1, progress.bar="text") {
  data_list = list(xy = cbind(x, y), n = length(x))
  # Use robust estimates of the parameters as initial values
  inits_list = list(mu=c(mean(x, trim=0.2), mean(y, trim=0.2)), rho=cor(x, y, method="spearman"), 
                    sigma = c(mad(x), mad(y)), nuMinusOne = 5)
  mcmc_samples <- run_jags(cor_model_string, data = data_list, inits = inits_list, 
                           params = c("rho", "mu", "sigma", "nu"), n.chains = n.chains, n.adapt = n.adapt,
                           n.update = n.update, n.iter = n.iter, thin = thin, progress.bar=progress.bar)
  mcmc_samples
}

#' @method bayes.cor.test default
#' @export
#' @rdname bayes.cor.test
bayes.cor.test.default <- function (x, y, alternative = c("two.sided", "less", "greater"), 
                                  method = c("pearson", "kendall", "spearman"), exact = NULL, 
                                  conf.level = 0.95, continuity = FALSE, n.iter = 15000, progress.bar="text",...) 
{
  ### BEGIN code from cor.test.default ###
  alternative <- match.arg(alternative)
  method <- match.arg(method)
  DNAME <- paste(deparse(substitute(x)), "and", deparse(substitute(y)))
  if (length(x) != length(y)) 
    stop("'x' and 'y' must have the same length")
  if (!is.numeric(x)) 
    stop("'x' must be a numeric vector")
  if (!is.numeric(y)) 
    stop("'y' must be a numeric vector")
  # removes uncomplete pairs, this shouldn't be neccessary if JAGS could handle missing data in dmvt
  OK <- complete.cases(x, y)
  x <- x[OK]
  y <- y[OK]
  n <- length(x)
  if (n < 3L) 
    stop("not enough observations. Need at least three complete observation.")
  ### END code from cor.test.default
  if (method == "kendall" || method == "spearman") {
    stop("no non-parametric correlation comparable to Kendall's tau or Spearman's rho has been implemented yet.")
  }
  mcmc_samples <- jags_cor_test(x, y, n.chains=3, n.iter=ceiling(n.iter / 3), progress.bar=progress.bar)
  bfa_result <- list(x = x, y = y, n = n, data_name = DNAME, mcmc_samples = mcmc_samples)
  class(bfa_result) <- c("bayes_cor_test", "bayesian_first_aid")
  bfa_result
  
}

#' @method bayes.cor.test formula
#' @export
#' @rdname bayes.cor.test
bayes.cor.test.formula <- function (formula, data, subset, na.action, ...) 
{
  ### BEGIN code from cor.test.formula ###
  if (missing(formula) || !inherits(formula, "formula") || 
        length(formula) != 2L) 
    stop("'formula' missing or invalid")
  m <- match.call(expand.dots = FALSE)
  if (is.matrix(eval(m$data, parent.frame()))) 
    m$data <- as.data.frame(data)
  m[[1L]] <- as.name("model.frame")
  m$... <- NULL
  mf <- eval(m, environment(formula))
  if (length(mf) != 2L) 
    stop("invalid formula")
  DNAME <- paste(names(mf), collapse = " and ")
  names(mf) <- c("x", "y")
  ### END code from cor.test.formula ###
  
  bfa_result <- do.call("bayes.cor.test.default", c(mf, list(...)))
  bfa_result$data_name <- DNAME
  bfa_result
}

### Cor test S3 methods ###

#' @export
print.bayes_cor_test <- function(x, ...) {
  cat("\n --- Bayesian first aid cor test ---\n\n")
  print(summary(x$mcmc_samples))
}

#' @export
summary.bayes_cor_test <- function(object, ...) {
  cat("\nSummary\n")
  print(object)
}

#' @export
plot.bayes_cor_test <- function(x, ...) {
  plot(x$mcmc_samples)
}

#' @export
diagnostics.bayes_cor_test <- function(fit) {
  plot(fit$mcmc_samples)
}

#' @export
model.code.bayes_cor_test <- function(fit) {
  print(jags_cor_test)
}
