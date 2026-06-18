process BUILD_COUNT_TABLE {
    tag "${subdir}"

    label 'python'
    publishDir { "${params.output}/${subdir}" }, mode: 'copy'

    input:
    tuple path(profiles), val(subdir)

    output:
    tuple path("counts.tsv"), val(subdir), emit: counts

    script:
    """
    build_count_table.py ${profiles} \\
        --min-prevalence ${params.rclr_min_prevalence} \\
        --min-total-count ${params.rclr_min_total_count} \\
        -o counts.tsv
    """
}
