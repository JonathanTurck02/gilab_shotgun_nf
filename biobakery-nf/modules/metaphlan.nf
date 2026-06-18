process METAPHLAN {
    tag "${sample_id}"

    // Route each run to its own results subdir. The very-sensitive-local outputs
    // (named *_sensitive*) always go to sensitive/; the primary run follows the mode.
    publishDir "${params.output}", mode: 'copy', saveAs: { fn ->
        fn.contains('_sensitive')
            ? "sensitive/metaphlan/${fn.replace('_sensitive', '')}"
            : "${params.mode == 'sensitive' ? 'sensitive' : 'default'}/metaphlan/${fn}"
    }

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_metaphlan_profile.tsv"),        emit: profile
    tuple val(sample_id), path("${sample_id}_metaphlan_profile_sensitive.tsv"), emit: profile_sensitive, optional: true
    path "${sample_id}_metaphlan.bowtie2.bz2",                               emit: bowtie2, optional: true
    path "${sample_id}_metaphlan_sensitive.bowtie2.bz2",                     emit: bowtie2_sensitive, optional: true

    script:
    def mode = params.mode ?: 'default'
    // Primary run preset: 'sensitive' uses very-sensitive-local, otherwise very-sensitive.
    def primary_ps = (mode == 'sensitive') ? 'very-sensitive-local' : 'very-sensitive'
    // 'both' adds a second run with the very-sensitive-local preset.
    def run_both = (mode == 'both') ? 'true' : 'false'
    def db_arg = params.metaphlan_db ? "--bowtie2db ${params.metaphlan_db}" : ""
    """
    metaphlan \\
        ${reads} \\
        --input_type fastq \\
        --offline \\
        ${db_arg} \\
        --nproc ${task.cpus} \\
        --bt2_ps ${primary_ps} \\
        -t rel_ab_w_read_stats \\
        --bowtie2out ${sample_id}_metaphlan.bowtie2.bz2 \\
        -o ${sample_id}_metaphlan_profile.tsv

    if [ "${run_both}" = "true" ]; then
        metaphlan \\
            ${reads} \\
            --input_type fastq \\
            --offline \\
            ${db_arg} \\
            --nproc ${task.cpus} \\
            --bt2_ps very-sensitive-local \\
            -t rel_ab_w_read_stats \\
            --bowtie2out ${sample_id}_metaphlan_sensitive.bowtie2.bz2 \\
            -o ${sample_id}_metaphlan_profile_sensitive.tsv
    fi
    """
}
