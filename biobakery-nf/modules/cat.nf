process CAT {
    tag "${sample_id}"

    publishDir "${params.output}/cat", mode: 'copy'

    input:
    tuple val(sample_id),
          path(paired_1),
          path(paired_2),
          path(unmatched_1),
          path(unmatched_2)

    output:
    tuple val(sample_id), path("${sample_id}_concat.fastq.gz"), emit: reads

    script:
    """
    cat ${paired_1} ${paired_2} ${unmatched_1} ${unmatched_2} > ${sample_id}_concat.fastq.gz

    # Remove KneadData intermediate files to free disk space
    rm -f ${paired_1} ${paired_2} ${unmatched_1} ${unmatched_2}
    """
}
