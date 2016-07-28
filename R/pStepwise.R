#' Easily access p-values from linear models
#'
#' This function gives the user easy access to p-values for specific predictors from a linear model.  It is mainly used
#' to easily pass p-values to other functions.
#'
#' @param pred the predictor from the linear model whose p-value is desired
#' @param fit a linear model of type "lm" containing the desired predictor
#' @return the p-value for the desired predictor from the linear model
#' @author Cory Langille <lang1729@gmail.com>
#' @seealso \code{lm}
#' @export
#'
extractp <- function(pred, fit) {
  predClasses = attr(fit$terms, "dataClasses")        #finds the predictors that are categorical variables
  fact = predClasses[names(predClasses) == pred]
  if(fact == "factor") {
    pvalues <- anova(fit)[,5]
    predList <- rownames(anova(fit))
    index <- which(predList == pred)
    return(pvalues[index])
  }else {
    pvalues <- summary(fit)$coefficients[,4]
    return(pvalues[names(pvalues)==pred])
  }
}



#' Create formulas from strings to be used in linear models
#'
#' This function takes a string and a linear model and either adds the predictor to the model, or removes it.
#'
#' @param pred the predictor to be added or removed from the current model
#' @param fitCurrent the current model to be updated
#' @param add by default adds the predictor to to the model.  add=F removes the predictor from the model
#' @return the updated model of type "lm"
#' @export
#'
fMaker <- function(pred, fitCurrent, add=T) {
  addNew <- as.formula(paste(".~.+", pred))
  remNew <- as.formula(paste(".~.-", pred))
  if(add) {
    return(update(fitCurrent, addNew))
  }  else {
    return(update(fitCurrent, remNew))
  }
}



#' Adds a single predictor to a linear model based on its p-value
#'
#' This function will try and add a new predictor to a current model.  A predictor will be added if it has minimum p-value among all predictors and its p-value is below a certain threshold
#'
#' @param fitCurrent the current model of type "lm"
#' @param fullmodel a linear model containing all possible predictors.  Typically of the form lm(y~., data=data)
#' @param aEnter the threshold for adding the predictor, set to 0.1 be default
#' @return an updated linear model of type "lm"
#' @export
#'
stepfwd <- function(fitCurrent, fullmodel, aEnter = 0.1) {
  predsIncluded <- rownames(anova(fitCurrent))                                                #list of predictors in current model
  predsFull <- rownames(anova(fullmodel))                                                     #list of predictors in full model
  predsExcluded <- setdiff(predsFull, predsIncluded)                                          #list of predictors not in current model
  pvals <- sapply(predsExcluded, function(x) as.numeric(extractp(x, fMaker(x, fitCurrent))))  #takes each predictor not in the current model, creates a new lm which includes it, and stores its respective p-value. Really ugly, but the only way I could make it work.
  pvals <- unlist(pvals)
  toAdd <- pvals[which(pvals==min(pvals))]
  if(length(toAdd)==0) return(fitCurrent)                                                     #returns original model if no new predictors are added
  if(toAdd <= aEnter) return(fMaker(names(toAdd), fitCurrent))                                #updates and returns new model with additional predictor
  return(fitCurrent)
}



#' Removes a single predictor from a linear model based on its p-value
#'
#' This function will try and remove a single predictor from a current linear model.  A predictor will be removed if it has maximal p-value and its p-value is greater than a certain threshold.
#'
#' @param fitCurrent the current model of type "lm"
#' @param fullmodel a linear model containing all possible predictors.  Typically of the form lm(y~., data=data)
#' @param aRemove the threshold for removing the predictor, set to 0.1 by default
#' @return an updated linear model of type "lm"
#' @export
#'
stepbwd <- function(fitCurrent, fullmodel, aRemove = 0.1) {
  predsIncluded <- rownames(anova(fitCurrent))                                      #predictors in current model
  predsIncluded <- predsIncluded[predsIncluded != "Residuals"]                      #removes "residuals" as a predictor
  pvalues <- sapply(predsIncluded, function(x) as.numeric(extractp(x, fitCurrent))) #checks the p-value for each predictor in current model
  toRemove <- pvalues[which(pvalues == max(pvalues))]                               #selects the predictor with maximal p-value
  if(toRemove > aRemove) return(fMaker(names(toRemove), fitCurrent, add=F))         #returns an updated model if the p-value is above the threshold
  return(fitCurrent)                                                                #else, returns original model
}

#' Selects the best predictors for a linear model based on p-values
#'
#' This function will create a linear model based on the p-values for each predictor.
#' @param response the response variable of interest in the model
#' @param fullmodel a linear model containing all possible predictors.  Typically of the form lm(y~., data=data)
#' @param aEnter the threshold for adding new predictors, set to 0.1 by default
#' @param aRemove the threshold for removing predictors from the current model, set to 0.1 by default
#' @return a linear model of type lm containing the "best" predictors
#' @author Cory Langille <lang1729@gmail.com>
#' @seealso extractp, stepfwd, stepbwd, fMaker
#' @export
#'
pStepwise <- function(response, fullmodel, aEnter = 0.1, aRemove = 0.1) {
  continue <- TRUE
  fitBwd <- lm(as.formula(paste(response, "~1")))           #creates an empty model to begin with
  while(continue){
    print("Trying to add another predictor")
    fitFwd = stepfwd(fitBwd, fullmodel)                     #try to add a predictor
    print(fitFwd$call)
    if(identical(fitFwd, fitBwd) == T) {                    #if no new predictors were added, it will stop
      return(fitFwd)
    }else {                                                 #try to remove a predictor
      print("Trying to remove a predictor")
      fitBwd = stepbwd(fitFwd, fullmodel)
    }
  }
}