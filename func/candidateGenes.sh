check_input_genes() {
	local gene_dir="$1"
	local candidate_genes="$2"
	local cmd_file="$3"
	local err_log="$4"
    
	while read -r input tag; do
		if [ ! -s "${gene_dir}/$input" ]; then
			echo "ERROR : check_input_genes [${cmd_file}]" >> "${err_log}"
		exit 1
		fi
	done < "${gene_dir}/${candidate_genes}"
}

create_temp_file() {
	local analysis_id="$1"
	local cmd_file="$2"
	local err_log="$3"
    
	mv -v "${analysis_id}.allchr.g.geno.norm.ann.tag.vcf.gz" "${analysis_id}.allchr.g.geno.norm.ann.tag.TMP0.vcf.gz"
	mv -v "${analysis_id}.allchr.g.geno.norm.ann.tag.vcf.gz.tbi" "${analysis_id}.allchr.g.geno.norm.ann.tag.TMP0.vcf.gz.tbi"
	if [ $? -ne 0 ]; then
		echo "ERROR : create_temp_file [${cmd_file}]" >> "${err_log}"
		exit 1
	fi
}

tag_variants_in_candidate_genes() {
	local analysis_id="$1"
	local gene_dir="$2"
	local candidate_genes="$3"
	local cmd_file="$4"
	local err_log="$5"
    
	module purge >&2
	module load Perl/5.34.1-GCCcore-11.3.0 >&2
	module load HTSlib/1.15.1-GCC-11.2.0 >&2
    
	local i=0
	local j=1
	while read -r input tag; do
		/scratch_isilon/groups/dat/apps/VCF1LINERS/tagVariantsInCandidateGenes \
		-i "${analysis_id}.allchr.g.geno.norm.ann.tag.TMP$i.vcf.gz" \
		-c "${gene_dir}/$input" \
		-t "$tag" \
		-o "${analysis_id}.allchr.g.geno.norm.ann.tag.TMP$j.vcf.gz"
		if [ $? -ne 0 ]; then
			echo "ERROR : tag_variants_in_candidate_genes [${cmd_file}]" >> "${err_log}"
		exit 1
		fi
		((i++))
		((j++))
	done < "${gene_dir}/${candidate_genes}"

	mv ${analysis_id}.allchr.g.geno.norm.ann.tag.TMP$i.vcf.gz ${analysis_id}.allchr.g.geno.norm.ann.tag.vcf.gz
	if [ $? -ne 0 ]; then 
		echo "ERROR : tag_variants_in_candidate_genes [${cmd_file}]" >> "${err_log}"
		exit 1
	fi
}

tag_annotsv_in_candidate_genes() {
	local analysis_id="$1"
	local prog_id="$2"
	local gene_dir="$3"
	local candidate_genes="$4"
	local cmd_file="$5"
	local err_log="$6"
    
	module purge >&2
	module load Python/3.9.6-GCCcore-11.2.0 >&2
	module load SciPy-bundle/2021.10-foss-2021b >&2
	source /scratch_isilon/groups/dat/apps/ANNOTSVTOOLS/annotsvtools_venv/bin/activate >&2
    
    local j=1
	while read input tag; do \
		/scratch_isilon/groups/dat/apps/ANNOTSVTOOLS/tagVariantsInCandidateGenesAnnotSV \
		-I "${analysis_id}.${prog_id}.annot.tag.tsv" \
		-c "${gene_dir}/$input" \
		-t "$tag" \
		-O "${analysis_id}.${prog_id}.annot.tag.tsv"
		if [ $? -ne 0 ]; then
			echo "ERROR : tag_annotsv_in_candidate_genes [${cmd_file}]" >> "${err_log}"
		exit 1
		fi
		((j++))
	done < "${gene_dir}/${candidate_genes}"
}
