# Internal interpreter for the sce-filter job. Rules are data, never R source.
.read_metadata_filters <- function(file) {
    fail <- function(msg) stop("metadata_filters: ", msg, call. = FALSE)
    size <- file.info(file)$size
    if (length(size) != 1L || is.na(size) || size > 1048576L)
        fail("file must be readable and at most 1048576 bytes")
    con <- file(file, "rb")
    on.exit(close(con))
    bytes <- readBin(con, "raw", n = 1048577L)
    if (length(bytes) > 1048576L) fail("file exceeds 1048576 bytes")
    # Bound parser nesting before parsing (32 predicate levels can include arrays).
    quoted <- escaped <- FALSE
    depth <- 0L
    for (b in as.integer(bytes)) {
        if (quoted) {
            if (escaped) escaped <- FALSE
            else if (b == 92L) escaped <- TRUE
            else if (b == 34L) quoted <- FALSE
        } else if (b == 34L) quoted <- TRUE
        else if (b %in% c(123L, 91L)) {
            depth <- depth + 1L
            if (depth > 66L) fail("JSON nesting exceeds parser safety limit (66)")
        } else if (b %in% c(125L, 93L)) depth <- depth - 1L
    }
    tryCatch(jsonlite::parse_json(rawToChar(bytes), simplifyVector = FALSE),
        error = function(e) fail(paste("invalid JSON:", conditionMessage(e))))
}

.metadata_filter_masks <- function(rules, rowdata, coldata) {
    object <- function(x) is.list(x) && !is.null(names(x))
    count <- 0L
    interpret <- function(node, data, path, depth = 1L, section = FALSE) {
        field <- if (is.list(node) && is.character(node$field) && length(node$field) == 1L)
            paste0(" [field '", node$field, "']") else ""
        fail <- function(msg) stop(path, field, ": ", msg, call. = FALSE)
        if (!object(node) || anyDuplicated(names(node)))
            fail("expected an object with unique keys")
        if (section && length(node) == 0L) return(rep(TRUE, nrow(data)))
        count <<- count + 1L
        if (count > 10000L) fail("total predicate count exceeds 10000")
        if (depth > 32L) fail("predicate nesting exceeds 32 levels")
        keys <- names(node)
        if (length(keys) == 1L && keys %in% c("all", "any", "not")) {
            kind <- keys[[1L]]
            if (kind == "not") {
                ans <- !interpret(node[[kind]], data, paste0(path, ".not"), depth + 1L)
            } else {
                children <- node[[kind]]
                if (!is.list(children) || !is.null(names(children)) || !length(children))
                    fail(paste0(kind, " requires a nonempty array of predicates"))
                ans <- rep(kind == "all", nrow(data))
                for (i in seq_along(children)) {
                    child <- interpret(children[[i]], data,
                        paste0(path, ".", kind, "[", i, "]"), depth + 1L)
                    ans <- if (kind == "all") ans & child else ans | child
                }
            }
        } else {
            if (!is.character(node$field) || length(node$field) != 1L ||
                !is.character(node$op) || length(node$op) != 1L)
                fail("expected scalar string field and op")
            op <- node$op
            if (!op %in% c("gt", "ge", "lt", "le", "eq", "ne", "in", "is_missing"))
                fail(paste0("unsupported operator '", op, "'"))
            expected <- if (op == "is_missing") c("field", "op") else c("field", "op", "value")
            if (!setequal(keys, expected)) fail(paste("expected exactly keys:", paste(expected, collapse = ", ")))
            index <- which(names(data) == node$field)
            if (length(index) != 1L) fail("field must identify exactly one metadata column")
            x <- data[[index]]
            if (identical(class(x), "factor") || identical(class(x), c("ordered", "factor"))) x <- as.character(x)
            type <- function(x) {
                if (is.object(x) || !is.null(dim(x))) return("unsupported")
                if (typeof(x) %in% c("integer", "double")) "numeric"
                else if (typeof(x) %in% c("character", "logical")) typeof(x)
                else "unsupported"
            }
            xtype <- type(x)
            if (xtype == "unsupported" || length(x) != nrow(data))
                fail("column must be an ordinary numeric, character, logical vector or factor")
            if (op == "is_missing") ans <- is.na(x)
            else {
                scalar <- function(v) length(v) == 1L && type(v) != "unsupported" &&
                    !anyNA(v) && (!is.numeric(v) || is.finite(v))
                value <- node$value
                if (op == "in") {
                    if (!is.list(value) || !is.null(names(value)) || !length(value) ||
                        !all(vapply(value, scalar, logical(1))))
                        fail("in requires a nonempty array of non-null scalar literals")
                    types <- vapply(value, type, character(1))
                    if (length(unique(types)) != 1L) fail("in literals must have consistent types")
                    value <- unlist(value, use.names = FALSE)
                } else if (!scalar(value)) fail("comparison requires a finite non-null scalar literal")
                if (type(value) != xtype) fail("literal type must match column type")
                if (op %in% c("gt", "ge", "lt", "le") && xtype != "numeric")
                    fail("ordering comparisons require a numeric column")
                ans <- switch(op, gt = x > value, ge = x >= value,
                    lt = x < value, le = x <= value, eq = x == value,
                    ne = x != value, `in` = x %in% value)
                ans[is.na(x)] <- NA
            }
        }
        if (!is.logical(ans) || !is.null(dim(ans)) || length(ans) != nrow(data))
            fail("predicate must produce one logical value per metadata row")
        ans
    }
    if (!object(rules) || anyDuplicated(names(rules)) ||
        !setequal(names(rules), c("rowdata", "coldata")))
        stop("metadata_filters: expected exactly rowdata and coldata sections", call. = FALSE)
    rows <- interpret(rules$rowdata, rowdata, "$.rowdata", section = TRUE)
    cols <- interpret(rules$coldata, coldata, "$.coldata", section = TRUE)
    rows[is.na(rows)] <- FALSE
    cols[is.na(cols)] <- FALSE
    list(rows = rows, cols = cols)
}
