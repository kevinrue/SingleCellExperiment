# Getter/setter functions for reducedDims.

.red_key <- "reducedDims"

#' @export
#' @importFrom S4Vectors List
#' @importClassesFrom S4Vectors SimpleList
setMethod("reducedDims", "SingleCellExperiment", function(x, withDimnames=TRUE) {
    x <- updateObject(x)
    value <- as(int_colData(x)[[.red_key]], "SimpleList")
    if (withDimnames) {
        for (i in seq_along(value)) {
            rownames(value[[i]]) <- colnames(x)
        }
    }
    value
})

#' @export
#' @importFrom methods as
#' @importFrom S4Vectors DataFrame
setReplaceMethod("reducedDims", "SingleCellExperiment", function(x, value) {
    x <- updateObject(x)

    if (length(value)==0L) {
        collected <- int_colData(x)[,0]
    } else {
        nrows <- vapply(value, nrow, FUN.VALUE = 0L)
        if (!all(nrows == ncol(x))) {
            stop("elements of replacement 'reducedDims' do not have the correct number of rows")
        }
        collected <- do.call(DataFrame, lapply(value, I))
        if (is.null(names(value))) {
            colnames(collected) <- character(length(value))
        }
    }

    int_colData(x)[[.red_key]] <- collected
    x
})

#' @export
setMethod("reducedDimNames", "SingleCellExperiment", function(x) {
    x <- updateObject(x)
    colnames(int_colData(x)[[.red_key]])
})

#' @export
setReplaceMethod("reducedDimNames", c("SingleCellExperiment", "character"), function(x, value) {
    x <- updateObject(x)
    colnames(int_colData(x)[[.red_key]]) <- value
    x
})

#' @export
setMethod("reducedDim", "SingleCellExperiment", function(x, type=1, withDimnames=TRUE) {
    x <- updateObject(x)

    internals <- int_colData(x)[[.red_key]]
    out <- internals[,type]
    if (!is.null(out) && withDimnames) {
        rownames(out) <- colnames(x)
    }
    out
})

#' @export
setReplaceMethod("reducedDim", "SingleCellExperiment", function(x, type=1, ..., value) {
    x <- updateObject(x)

    internals <- int_colData(x)
    if (!is.null(value) && !identical(nrow(value), ncol(x))) {
        stop("replacement 'reducedDim' has a different number of rows than 'ncol(x)'")
    }
    internals[[.red_key]][[type]] <- value
    int_colData(x) <- internals
    x
})
