#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// PARAMS
params.input        = "$projectDir/data"
params.pattern      = "*_R{1,2}*.fastq.gz"
params.output       = "$projectDir/results"
params.kneaddata_db = "/scratch/user/jonathanturck/03_resources/dog_host/dog" // update location
params.batch        = 0      // number of sample pairs to process (0 = all)

// IMPORT MODULES
include { FASTP          } from './modules/fastp.nf'
include { KNEADDATA      } from './modules/kneaddata.nf'
include { CAT            } from './modules/cat.nf'
include { METAPHLAN      } from './modules/metaphlan.nf'
include { MERGE_PROFILES } from './modules/merge_profiles.nf'
include { BUILD_COUNT_TABLE } from './modules/build_count_table.nf'

// WORKFLOW
workflow {

    // Create a channel of [sample_id, [R1, R2]] from paired-end FASTQs
    // Strip the project ID (e.g. _CMD01166) from the sample name
    reads_ch = Channel
        .fromFilePairs("${params.input}/${params.pattern}", checkIfExists: true)
        .map { sample_id, reads ->
            def clean_id = sample_id.replaceAll(/_CMD\d+/, '')
            [ clean_id, reads ]
        }

    // Optionally limit to a batch of N samples
    if ( params.batch > 0 ) {
        reads_ch = reads_ch.take(params.batch)
    }

    // Step 1 – Adapter trimming & quality filtering
    FASTP(reads_ch)

    // Step 2 – Host decontamination
    KNEADDATA(FASTP.out.reads)

    // Step 3 – Concatenate paired + unmatched KneadData outputs into one file per sample
    CAT(KNEADDATA.out.reads)

    // Step 4 – Taxonomic profiling
    METAPHLAN(CAT.out.reads)

    // ── Count-table tail ──
    // The count table is built across all samples at once: collect every per-sample
    // profile into one task. Each tuple carries (profiles, subdir); the subdir threads
    // through every process so each sensitivity run publishes to its own results folder.
    // In 'sensitive' mode the single run uses very-sensitive-local, so it lands in sensitive/.
    primary_subdir = ( params.mode == 'sensitive' ) ? 'sensitive' : 'default'
    default_ch = METAPHLAN.out.profile
        .map { _id, tsv -> tsv }
        .collect()
        .map { tuple(it, primary_subdir) }

    // In 'both' mode, add the very-sensitive-local profiles as a second item in the channel.
    if ( params.mode == 'both' ) {
        sensitive_ch = METAPHLAN.out.profile_sensitive
            .map { _id, tsv -> tsv }
            .collect()
            .map { tuple(it, 'sensitive') }
        merge_in = default_ch.mix(sensitive_ch)
    } else {
        merge_in = default_ch
    }

    // MERGE_PROFILES emits a standard merged relative-abundance table for inspection.
    // BUILD_COUNT_TABLE reads the per-sample profiles directly (not the merged file):
    // some merge_metaphlan_tables.py builds drop the read-stats columns, and the
    // estimated_number_of_reads_from_the_clade values we need live only in the
    // per-sample profiles.
    MERGE_PROFILES(merge_in)
    BUILD_COUNT_TABLE(merge_in)

    // Gemelli rCLR / RPCA is not run here. The count table (counts.tsv) is the only
    // input Gemelli needs, so it can be run separately/downstream from that file.
}

