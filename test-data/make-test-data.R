library(SingleCellExperiment)
library(anndataR)

nrows <- 10; ncols <- 5
set.seed(1)
counts <- matrix(rbinom(nrows * ncols, 5, 0.1), nrows)

colData <- DataFrame(
  sum = colSums(counts),
  detected = colSums(counts > 0),
  row.names = paste0('sample_', seq_len(ncol(counts)))
)

rowData <- DataFrame(
  ID = paste0("ID_", seq_len(nrow(counts))),
  Symbol = paste0("SYMBOL_", seq_len(nrow(counts))),
  row.names = paste0("ID_", seq_len(nrow(counts)))
)

sce <- SingleCellExperiment(
  assays = list(counts = counts),
  rowData = rowData,
  colData = colData
)

anndataR::write_h5ad(sce, "sce.h5ad", compression = "gzip")
