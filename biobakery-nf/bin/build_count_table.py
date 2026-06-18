#!/usr/bin/env python3
"""Build an integer count table from MetaPhlAn 4 rel_ab_w_read_stats profiles.

Input : one or more *_metaphlan_profile.tsv files produced with -t rel_ab_w_read_stats
Output: counts.tsv  (rows = taxon features, cols = samples, values = estimated reads)

By default features are summarised at the species level; pass --level (e.g. genus, family,
phylum) to use a different rank. MetaPhlAn emits one row per rank, so the chosen rank's
estimated_number_of_reads_from_the_clade is already the within-clade total at that rank.

Rationale: estimated_number_of_reads_from_the_clade is the read-like quantity that mirrors
a 16S count table going into Gemelli's rCLR/RPCA. See rclr_integration.md section 1.
"""
import argparse
import os
import sys
import pandas as pd

# MetaPhlAn taxonomic ranks, shallow -> deep. A clade row is "at" a given rank if its
# clade_name contains that rank's prefix but not the next-deeper rank's prefix (taxonomy is
# strictly nested, so excluding the immediate child rank excludes everything below it too).
_RANK_ORDER = [
    ("kingdom", "k__"),
    ("phylum",  "p__"),
    ("class",   "c__"),
    ("order",   "o__"),
    ("family",  "f__"),
    ("genus",   "g__"),
    ("species", "s__"),
    ("strain",  "t__"),
]

# Derive include/exclude regexes per level. The include allows the prefix either at the
# start of the string (the kingdom row has no leading '|') or after a '|'.
LEVELS = {}
for _i, (_name, _tok) in enumerate(_RANK_ORDER):
    LEVELS[_name] = {
        "include": rf"(?:^|\|){_tok}",
        "exclude": rf"\|{_RANK_ORDER[_i + 1][1]}" if _i + 1 < len(_RANK_ORDER) else None,
    }


def sample_name(path):
    base = os.path.basename(path)
    for suffix in ("_metaphlan_profile.tsv", "_metaphlan_profile_sensitive.tsv", ".tsv"):
        if base.endswith(suffix):
            return base[: -len(suffix)]
    return base


def read_profile(path, level="species"):
    header_idx = None
    with open(path) as fh:
        for i, line in enumerate(fh):
            if line.startswith("#clade_name") or line.startswith("clade_name"):
                header_idx = i
                break
    if header_idx is None:
        sys.exit(f"ERROR: no clade_name header found in {path}")

    df = pd.read_csv(path, sep="\t", skiprows=header_idx)
    df.columns = [c.lstrip("#").strip() for c in df.columns]

    read_col = "estimated_number_of_reads_from_the_clade"
    if read_col not in df.columns:
        sys.exit(
            f"ERROR: '{read_col}' not in {path}. "
            "Was MetaPhlAn run with '-t rel_ab_w_read_stats'?"
        )

    sel = LEVELS[level]
    is_level = df["clade_name"].str.contains(sel["include"])
    if sel["exclude"] is not None:
        is_level &= ~df["clade_name"].str.contains(sel["exclude"])
    df = df.loc[is_level, ["clade_name", read_col]].copy()

    df["feature"] = df["clade_name"].str.split("|").str[-1]
    s = df.set_index("feature")[read_col].astype(float).round().astype("Int64")
    s.name = sample_name(path)
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("profiles", nargs="+", help="per-sample profile TSVs (or one merged TSV)")
    ap.add_argument("-o", "--output", default="counts.tsv")
    ap.add_argument("--level", choices=sorted(LEVELS), default="species",
                    help="taxonomic level to summarise at (default: species)")
    ap.add_argument("--min-prevalence", type=float, default=0.0,
                    help="drop features present (nonzero) in fewer than this fraction of "
                         "samples (default: 0 = no filtering)")
    ap.add_argument("--min-total-count", type=int, default=0,
                    help="drop features whose total estimated reads across samples is below "
                         "this (default: 0 = no filtering)")
    args = ap.parse_args()

    series = [read_profile(p, args.level) for p in args.profiles]
    table = pd.concat(series, axis=1)
    table = table.fillna(0).astype(int)

    n_samples = table.shape[1]
    prevalence = (table > 0).sum(axis=1) / n_samples
    keep = (prevalence >= args.min_prevalence) & (table.sum(axis=1) >= args.min_total_count)
    table = table.loc[keep]

    table = table.loc[:, table.sum(axis=0) > 0]

    table.index.name = "#OTU ID"
    table.to_csv(args.output, sep="\t")
    sys.stderr.write(
        f"Wrote {args.output}: {table.shape[0]} {args.level} × {table.shape[1]} samples\n"
    )


if __name__ == "__main__":
    main()
