# bioBakery Nextflow Pipeline

A Nextflow (DSL2) pipeline for shotgun metagenomic analysis of paired-end FASTQ files. The pipeline performs adapter trimming, host decontamination, read concatenation, and taxonomic profiling using established bioBakery tools.

## Pipeline Overview

```
Raw paired-end reads (FASTQ)
        │
        ▼
   ┌─────────┐
   │  FASTP  │  Adapter trimming & quality filtering
   └────┬────┘
        ▼
  ┌───────────┐
  │ KNEADDATA │  Host read decontamination
  └─────┬─────┘
        ▼
    ┌───────┐
    │  CAT  │  Concatenate paired & unmatched reads
    └───┬───┘
        ▼
  ┌───────────┐
  │ METAPHLAN │  Taxonomic profiling
  └───────────┘
```

### Steps

| Step | Tool | Description |
|------|------|-------------|
| 1 | **fastp** (v0.23.4) | Adapter auto-detection and quality trimming for paired-end reads |
| 2 | **KneadData** (v0.12.2) | Removal of host-derived reads using a reference genome (e.g. dog, human) |
| 3 | **cat** | Concatenation of KneadData's paired and unmatched outputs into a single file per sample |
| 4 | **MetaPhlAn** (v4.2.4) | Marker-gene-based taxonomic profiling |

## Requirements

- [Nextflow](https://www.nextflow.io/) ≥ 25.04
- Access to an HPC environment with SLURM (or run locally with the `standard` profile)
- The following software (loaded via HPC modules or installed locally):
  - fastp
  - KneadData
  - MetaPhlAn

### Reference Databases

- **KneadData**: A Bowtie2-indexed reference genome for host read removal (set via `--kneaddata_db`)
- **MetaPhlAn**: The MetaPhlAn Bowtie2 database (set via `--metaphlan_db`, or uses the default database location)

## Configuration for New Users

Both `nextflow.config` and `initiate_pipe.sh` use the `$USER` environment variable to automatically resolve paths under `/scratch/user/$USER/`. No username changes are needed.

However, the following settings in `biobakery-nf/nextflow.config` assume a specific directory layout and may need to be adjusted:

| Setting | Default | Description |
|---------|---------|-------------|
| `params.input` | `$(pwd)/data` | Path to the directory containing your input FASTQ files (overridden by `initiate_pipe.sh --indir`) |
| `params.output` | `$(pwd)/results` | Path to the directory where results will be written (overridden by `initiate_pipe.sh --outdir`) |
| `params.kneaddata_db` | `/scratch/user/$USER/03_resources/dog_host/dog` | Path to the KneadData Bowtie2 reference database |
| `env.NXF_WORK` | `/scratch/user/$USER/.nextflow_work` | Nextflow work directory (scratch space for intermediate files) |


## Quick Start

### On an HPC cluster (SLURM)

The provided `initiate_pipe.sh` script submits the pipeline as a SLURM job:

```bash
sbatch initiate_pipe.sh [--batch N] [--indir DIR] [--outdir DIR]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--batch` | `0` (all) | Number of sample pairs to process |
| `--indir` | `$(pwd)/data` | Directory containing input FASTQ files |
| `--outdir` | `$(pwd)/results` | Directory for pipeline results |

```bash
# Process all samples from ./data, output to ./results
sbatch initiate_pipe.sh

# Process 50 samples from ./data, output to ./results
sbatch initiate_pipe.sh --batch 50

# Process all samples with custom directories
sbatch initiate_pipe.sh --indir /path/to/fastqs --outdir /path/to/output
```

### Running directly with Nextflow

```bash
nextflow run main.nf \
    -profile slurm \
    -resume \
    --input /path/to/fastqs \
    --kneaddata_db /path/to/host_db \
    --metaphlan_db /path/to/metaphlan_db \
    --batch 50
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--input` | `$projectDir/data` | Directory containing input FASTQ files |
| `--pattern` | `*_R{1,2}*.fastq.gz` | Glob pattern for pairing R1/R2 reads |
| `--output` | `$projectDir/results` | Output directory for results |
| `--kneaddata_db` | `null` | Path to KneadData Bowtie2 reference database |
| `--metaphlan_db` | `null` | Path to MetaPhlAn Bowtie2 database |
| `--batch` | `0` | Number of sample pairs to process (`0` = all). Pass via `initiate_pipe.sh --batch` or when running Nextflow directly. |

## Profiles

| Profile | Description |
|---------|-------------|
| `standard` | Run locally |
| `slurm` | Submit jobs to a SLURM cluster |

## Resource Allocation

| Process | CPUs | Memory | Time |
|---------|------|--------|------|
| FASTP | 4 | 8 GB | 1 h |
| KNEADDATA | 8 | 32 GB | 4 h |
| CAT | 1 | 4 GB | 30 min |
| METAPHLAN | 8 | 32 GB | 3 h |

A maximum of 20 SLURM jobs are submitted concurrently (with a 20-second submit rate limit) to manage disk usage.

## Output Structure

```
results/
├── fastp/
│   ├── <sample>_fastp.html       # QC report (HTML)
│   └── <sample>_fastp.json       # QC report (JSON)
├── kneaddata/
│   └── <sample>_kneaddata.log    # Decontamination log
├── cat/
│   └── <sample>_concat.fastq.gz  # Concatenated clean reads
├── metaphlan/
│   ├── <sample>_metaphlan_profile.tsv    # Taxonomic profile
│   └── <sample>_metaphlan.bowtie2.bz2   # Bowtie2 alignment (optional)
└── pipeline_info/
    ├── timeline.html             # Execution timeline
    └── report.html               # Nextflow run report
```

## Disk Management

The pipeline is configured for large datasets with limited disk quotas:

- **`cleanup = true`**: Intermediate work directory files are removed once all downstream processes have consumed them.
- **KneadData** runs in `$TMPDIR` to avoid filling the Nextflow work directory with temporary files.
- **CAT** removes its input intermediates after concatenation.
- **SLURM queue size** is capped at 30 to prevent excessive intermediate file accumulation.

## Resuming a Run

Nextflow supports resuming from cached results. Use the `-resume` flag (included by default in `initiate_pipe.sh`) to skip already-completed samples:

```bash
nextflow run main.nf -profile slurm -resume
```
