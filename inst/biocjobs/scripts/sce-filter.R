## BiocJobs job script: sce-filter
## The declared interface lives in ../sce-filter.yaml; jobParams() parses the
## command line against it, so every value below is typed, validated and
## defaulted by the time it returns.

## Test command (R, from the repository root after installing this checkout)
## BiocJobs::runJob(BiocJobs::readJob("inst/biocjobs/sce-filter.yaml"), params = list(infile = "test-data/sce.h5ad", metadata_filters = "test-data/metadata-filters.json", outfile = "sce.filter.h5ad"))

## Regenerate wrappers with BiocJobs::biocjobsCLI() after changing the job spec.
if (any(grepl("^--(rowdata|coldata)(=|$)", commandArgs(trailingOnly = TRUE))))
    stop("--rowdata and --coldata were removed; use --metadata_filters with JSON rowdata and coldata sections", call. = FALSE)

params <- BiocJobs::jobParams("SingleCellExperiment", "sce-filter")

## -- your analysis ---------------------------------------------------------
## Read inputs from params$<input name>, honour params$<option name>, and
## write every declared output to params$<output name>. Fail loudly with
## stop() on bad input; never prompt or open devices interactively.

suppressPackageStartupMessages({
  library(anndataR)
  library(SummarizedExperiment)
})

sce <- anndataR::read_h5ad(params$infile, as = "SingleCellExperiment")

# Load trusted installed job support code into this job's environment.
source(system.file("biocjobs", "scripts", "metadata-filters.R",
    package = "SingleCellExperiment", mustWork = TRUE), local = TRUE)

rules <- .read_metadata_filters(params$metadata_filters)
masks <- .metadata_filter_masks(
    rules, SummarizedExperiment::rowData(sce), SummarizedExperiment::colData(sce))
sce <- sce[masks$rows, masks$cols, drop = FALSE]

tryCatch(anndataR::write_h5ad(sce, params$outfile, compression = "gzip"),
    error = function(e) stop("H5AD output failed for ", nrow(sce), " retained rows and ",
        ncol(sce), " retained columns: ", conditionMessage(e), call. = FALSE))

## Provenance to the job log.
message(paste(utils::capture.output(utils::sessionInfo()), collapse = "\n"))
