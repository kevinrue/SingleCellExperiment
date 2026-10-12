# sce-filter: JSON metadata predicates (breaking change in job 0.2.0)

Run the job with `--infile input.h5ad --metadata_filters metadata-filters.json
--outfile output.h5ad`. Both file inputs are required. The generated Nextflow
process takes one tuple: `tuple(meta, infile, metadata_filters)`, with both files
staged using `path`. Regenerate wrappers after changing the job specification:

```sh
Rscript -e 'BiocJobs::biocjobsCLI()' nextflow . sce-filter --image ghcr.io/kevinrue/singlecellexperiment:devel --out wrappers/sce-filter.nf
Rscript -e 'BiocJobs::biocjobsCLI()' galaxy . sce-filter --out wrappers/sce-filter.xml
```

The [v1 JSON Schema](schemas/metadata-filters-v1.schema.json) describes the format.
Exactly `rowdata` and `coldata` are required; `{}` disables that dimension.
An empty array or `null` does not disable filtering. Duplicate and unknown keys
are rejected. Each object must contain exactly one of these forms:

- `{"field":"detected","op":"gt","value":200}`: `gt`, `ge`, `lt`, `le`,
  `eq`, or `ne` with one scalar literal.
- `{"field":"group","op":"in","value":["A","B"]}`: nonempty array of
  consistently typed literals.
- `{"field":"group","op":"is_missing"}`: no value key.
- `{"all":[...]}` or `{"any":[...]}`: nonempty array of predicates.
- `{"not":{...}}`: one predicate.

Fields are exact, unique metadata column names (including spaces/punctuation).
Supported columns are ordinary numeric, character and logical vectors, and
factors explicitly converted to character. Other classes, arrays and list
columns are rejected. Literals must match the column type; integer and double
are both numeric. Ordering is numeric only. No string-to-number coercion occurs.
Null and nonfinite literals are invalid; use `is_missing` for missing values.

Comparisons, including `in`, return unknown (`NA`) on missing metadata.
`is_missing` always returns true or false. Boolean nodes use R's three-valued
logic: false AND unknown is false; true OR unknown is true; NOT unknown remains
unknown. Only after the complete tree is evaluated are remaining unknowns
converted to false. Both masks are evaluated against the original metadata
before subsetting together, preserving assay and metadata alignment.
Empty results are allowed and passed to the H5AD writer; writer failures are
reported as errors with the retained dimensions.

Limits: 1,048,576 bytes per file, 32 predicate levels (section root is level 1),
and 10,000 predicate nodes across both sections. A preparse safety check also
limits JSON container nesting to 66. Runtime checks enforce these limits,
unique keys, finite literals, metadata compatibility and vector lengths;
JSON Schema validation alone is insufficient. Errors include the rule path
and field where applicable. Neither rule strings nor operator names are
executed as code.

## Migration and examples

`--rowdata` and `--coldata` are removed and rejected with migration guidance.
There is no legacy expression fallback. Replace `sum > 5 & detected > 2` with
[test-data/metadata-filters.json](../../test-data/metadata-filters.json) in the
source repository. The [QC example](examples/qc-filters.json) replaces
`detected > 200 & detected < 2500 & subset.proportion.MT < 0.05`.
With nonmissing metadata these select the same cells as the old expressions.

The interpreter is job support code in `scripts/metadata-filters.R`, loaded
only by the job. Its jsonlite dependency is declared in the job specification.

A runnable pipeline example is in [examples/sce-filter.nf](examples/sce-filter.nf).
Run it from the source repository:

```sh
# Install this checkout and its job dependencies in the R library first.
R CMD INSTALL .
nextflow run inst/biocjobs/examples/sce-filter.nf --outdir results
```

For container execution, set `process.container` to an image containing this
checkout, BiocJobs, anndataR and jsonlite and enable the relevant executor.
