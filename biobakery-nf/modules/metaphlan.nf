process METAPHLAN {
    tag "${sample_id}"

    publishDir "${params.output}/metaphlan", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_metaphlan_profile.tsv"), emit: profile
    tuple val(sample_id), path("${sample_id}_metaphlan.bowtie2.bz2"), emit: bowtie2, optional: true

    script:
    def db_arg = params.metaphlan_db ? "--bowtie2db ${params.metaphlan_db}" : ""
    """
    metaphlan \\
        ${reads} \\
        --input_type fastq \\
        --offline \\
        --nproc ${task.cpus} \\
        --bowtie2out ${sample_id}_metaphlan.bowtie2.bz2 \\
        -o ${sample_id}_metaphlan_profile.tsv
    """
}
