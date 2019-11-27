
#' Rank Product/Rank Sum Analysis for Metabolomics
#'
#' @description PomaRankProd() performs the Rank Product method to identify differential metabolite concentration.
#'
#' @param data A data frame with metabolites. First column must be the subject ID and second column must be a TWO-FACTOR variable with the subject group.
#' @param logged If "TRUE" (default) data have been previously log transformed.
#' @param logbase Numerical. Base for log transformation.
#' @param paired Number of random pairs generated in the function, if set to NA (default), the odd integer closer to the square of the number of replicates is used.
#' @param cutoff The pfp threshold value used to select metabolites.
#' @param method If cutoff is provided, the method needs to be selected to identify metabolites. "pfp" uses percentage of false prediction, which is a default setting. "pval" uses p-values which is less stringent than pfp.
#'
#' @export
#'
#' @return A list with all results for Rank Product analysis including tables and plots.
#' @references Breitling, R., Armengaud, P., Amtmann, A., and Herzyk, P.(2004) Rank Products: A simple, yet powerful, new method to detect differentially regulated genes in replicated microarray experiments, FEBS Letter, 57383-92
#' @author Pol Castellano-Escuder
PomaRankProd <- function(data,
                         logged = TRUE,
                         logbase = 2,
                         paired = NA,
                         cutoff = 0.05,
                         method = c("pfp", "pval")){

  if (missing(data)) {
    stop(crayon::red(clisymbols::symbol$cross, "Select some data!"))
  }
  if (!(method %in% c("pfp", "pval"))) {
    stop(crayon::red(clisymbols::symbol$cross, "Incorrect value for method argument!"))
  }
  if (missing(method)) {
    method <- "pfp"
    warning("method argument is empty! pfp method will be used")
  }

  colnames(data)[1:2] <- c("ID", "Group")

  if (length(levels(as.factor(data$Group))) > 2) {
    stop(crayon::red(clisymbols::symbol$cross, "Your data has more than two groups!"))
  }

  data.cl <- as.numeric(as.factor(data$Group))
  data.cl[data.cl == 1] <- 0
  data.cl[data.cl == 2] <- 1

  class1 <- levels(as.factor(data$Group))[1]
  class2 <- levels(as.factor(data$Group))[2]

  names <- make.names(data$ID, unique = TRUE)

  data <- data %>% dplyr::select(-ID, -Group)
  data <- t(data)
  colnames(data) <- names

  RP <- RankProducts(data, data.cl, logged = logged, na.rm = TRUE, plot = FALSE,
                     RandomPairs = paired,
                     rand = 123,
                     gene.names = rownames(data))

  top_rank <- topGene(RP, cutoff = cutoff, method = method,
                      logged = logged, logbase = logbase,
                      gene.names = rownames(data))

  one <- as.data.frame(top_rank$Table1)
  two <- as.data.frame(top_rank$Table2)

  colnames(one)[3] <- paste0("FC: ", class1, "/", class2)
  colnames(two)[3] <- paste0("FC: ", class1, "/", class2)

  one <- one %>% dplyr::select(-gene.index)
  two <- two %>% dplyr::select(-gene.index)

  #### PLOT

  pfp <- as.matrix(RP$pfp)

  ####

  if (is.null(RP$RPs)) {
    RP1 <- as.matrix(RP$RSs)
    rank <- as.matrix(RP$RSrank)
  }

  if (!is.null(RP$RPs)){
    RP1 <- as.matrix(RP$RPs)
    rank <- as.matrix(RP$RPrank)
  }

  ind1 <- which(!is.na(RP1[, 1]))
  ind2 <- which(!is.na(RP1[, 2]))
  ind3 <- append(ind1, ind2)
  ind3 <- unique(ind3)
  RP.sort.upin2 <- sort(RP1[ind1, 1], index.return = TRUE)
  RP.sort.downin2 <- sort(RP1[ind2, 2], index.return = TRUE)
  pfp1 <- pfp[ind1, 1]
  pfp2 <- pfp[ind2, 2]
  rank1 <- rank[ind1, 1]
  rank2 <- rank[ind2, 2]

  rp_plot <- data.frame(rank1 = rank1, rank2 = rank2, pfp1 = pfp1 ,  pfp2 = pfp2)

  plot1 <- ggplot(rp_plot, aes(x = rank1, y = pfp1)) +
    geom_point(size = 1.5, alpha=0.8) +
    theme_minimal() +
    xlab("Number of identified metabolites") +
    ylab("Estimated PFP") +
    ggtitle(paste0("Identification of Up-regulated metabolites under class ", class2))

  plot2 <- ggplot(rp_plot, aes(x = rank2, y = pfp2)) +
    geom_point(size = 1.5, alpha=0.8) +
    theme_minimal() +
    xlab("Number of identified metabolites") +
    ylab("Estimated PFP") +
    ggtitle(paste0("Identification of Down-regulated metabolites under class ", class2))

  return(list(upregulated = one,
              downregulated = two,
              Upregulated_RP_plot = plot1,
              Downregulated_RP_plot = plot2))

}
