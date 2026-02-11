#!/bin/bash
#SBATCH --job-name=biobakery_nf
#SBATCH --output=biobakery_nf_%j.out
#SBATCH --error=biobakery_nf_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=1

# ── Environment setup ──
export NXF_ASSETS="$SCRATCH/.nextflow"
export NXF_WORK="/scratch/user/$USER/.nextflow_work"
export NXF_OPTS="-Xms1g -Xmx4g"

# ── Load HPC modules ──
module purge
module load Nextflow/25.04.6
module load WebProxy

# ── Defaults ──
BATCH_SIZE=0
INPUT_DIR="$(pwd)/data"
OUTPUT_DIR="$(pwd)/results"

usage() {
    echo "Usage: sbatch initiate_pipe.sh [--batch N] [--indir DIR] [--outdir DIR]"
    echo "Defaults: --batch 0 --indir $(pwd)/data --outdir $(pwd)/results"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --batch)
            [[ -n "${2:-}" ]] || { echo "Missing value for --batch"; usage; exit 1; }
            BATCH_SIZE="$2"
            shift 2
            ;;
        --indir)
            [[ -n "${2:-}" ]] || { echo "Missing value for --indir"; usage; exit 1; }
            INPUT_DIR="$2"
            shift 2
            ;;
        --outdir)
            [[ -n "${2:-}" ]] || { echo "Missing value for --outdir"; usage; exit 1; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ── Run pipeline ──
nextflow run "biobakery-nf/main.nf" \
    -profile slurm \
    -resume \
    --batch ${BATCH_SIZE} \
    --input "${INPUT_DIR}" \
    --output "${OUTPUT_DIR}"
