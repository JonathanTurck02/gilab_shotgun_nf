process MERGE_PROFILES {
    tag "${subdir}"

    label 'metaphlan'
    publishDir { "${params.output}/${subdir}" }, mode: 'copy'

    input:
    tuple path(profiles), val(subdir)

    output:
    tuple path("merged_profiles.tsv"), val(subdir), emit: merged

    script:
    """
    merge_metaphlan_tables.py ${profiles} > merged_profiles.tsv
    """
}
