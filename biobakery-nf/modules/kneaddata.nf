process KNEADDATA {
    tag "${sample_id}"

    // Only publish the log — intermediate FASTQs are consumed by CAT then cleaned up
    publishDir "${params.output}/kneaddata", mode: 'copy', pattern: "*.log"

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id),
          path("${sample_id}_paired_1.fastq.gz"),
          path("${sample_id}_paired_2.fastq.gz"),
          path("${sample_id}_unmatched_1.fastq.gz"),
          path("${sample_id}_unmatched_2.fastq.gz"), emit: reads
    path "${sample_id}_kneaddata.log",               emit: log

    script:
    def db_arg = params.kneaddata_db ? "--reference-db ${params.kneaddata_db}" : ""
    """
    # Run KneadData in \$TMPDIR to avoid filling work dir with temp files
    KNEADDATA_TMP=\${TMPDIR:-/tmp}/${sample_id}_kneaddata_tmp
    mkdir -p \${KNEADDATA_TMP}

    kneaddata \\
        --input1 ${reads[0]} \\
        --input2 ${reads[1]} \\
        ${db_arg} \\
        --output \${KNEADDATA_TMP} \\
        --output-prefix ${sample_id}_kneaddata \\
        --threads ${task.cpus} \\
        --trimmomatic-options "SLIDINGWINDOW:4:20 MINLEN:50"

    # Copy only final outputs back to the Nextflow work dir
    pigz -c \${KNEADDATA_TMP}/${sample_id}_kneaddata_paired_1.fastq > ${sample_id}_paired_1.fastq.gz
    pigz -c \${KNEADDATA_TMP}/${sample_id}_kneaddata_paired_2.fastq > ${sample_id}_paired_2.fastq.gz
    pigz -c \${KNEADDATA_TMP}/${sample_id}_kneaddata_unmatched_1.fastq > ${sample_id}_unmatched_1.fastq.gz
    pigz -c \${KNEADDATA_TMP}/${sample_id}_kneaddata_unmatched_2.fastq > ${sample_id}_unmatched_2.fastq.gz
    cp \${KNEADDATA_TMP}/${sample_id}_kneaddata.log ${sample_id}_kneaddata.log

    # Clean up all temp files
    rm -rf \${KNEADDATA_TMP}
    """
}
