## BiocJobs job script: sce-filter
## The declared interface lives in ../sce-filter.yaml; jobParams() parses the
## command line against it, so every value below is typed, validated and
## defaulted by the time it returns.

## Test command (R)
## BiocJobs::runJob(BiocJobs::readJob("inst/biocjobs/sce-filter.yaml"), params = list(infile = "test-data/sce.h5ad", coldata = "sum > 5 & detected > 2", rowdata = " ", outfile = "sce.filter.h5ad"))

## Validation command (Bash)
## Rscript -e 'BiocJobs::biocjobsCLI()' validate .

# Rscript -e 'BiocJobs::biocjobsCLI()' galaxy   . sce-filter --out wrappers/sce-filter.xml
# Rscript -e 'BiocJobs::biocjobsCLI()' nextflow . sce-filter --out wrappers/sce-filter.nf

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

if (!identical(params$rowdata, " ")) {
  keep <- eval(parse(text = params$rowdata), envir = SummarizedExperiment::rowData(sce))
  sce <- sce[keep, ]
}

if (!identical(params$coldata, " ")) {
  keep <- eval(parse(text = params$coldata), envir = SummarizedExperiment::colData(sce))
  sce <- sce[, keep]
}

anndataR::write_h5ad(sce, params$outfile, compression = "gzip")

## Provenance to the job log.
message(paste(utils::capture.output(utils::sessionInfo()), collapse = "\n"))
