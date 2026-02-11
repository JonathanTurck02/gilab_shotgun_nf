#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// PARAMS
params.input        = "$projectDir/data"
params.pattern      = "*_R{1,2}*.fastq.gz"
params.output       = "$projectDir/results"
params.kneaddata_db = null   // path to KneadData reference DB (e.g. human genome)
params.metaphlan_db = null   // path to MetaPhlAn bowtie2 database
params.batch        = 0      // number of sample pairs to process (0 = all)

// IMPORT MODULES
include { FASTP     } from './modules/fastp.nf'
include { KNEADDATA } from './modules/kneaddata.nf'
include { CAT       } from './modules/cat.nf'
include { METAPHLAN } from './modules/metaphlan.nf'

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
}

