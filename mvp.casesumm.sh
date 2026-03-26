	touch ${casesummLog}
	
	echo "# INFO - Launching Case Summarizer for MVPGermline results [${now}] ..." | tee -a ${casesummLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${casesummLog}
	
	echo "# INFO - Submitting casesumm by sample ..." | tee -a ${casesummLog}
	while read pedigree; do	
		while read ped sample app sex bcam gvcf vcf; do
			stepDir="${anaDir}/${pedigree}/casesumm/${sample}"
			jobLab="${sample}.casesumm"
			jobCmd="${stepDir}/${jobLab}.cmd"
			jobLog="${stepDir}/${jobLab}.jobID.log"
			errLog="${stepDir}/ERROR.log"
			mkdir -p ${stepDir}
			apptainer run --no-home --bind ${bindDir} ${contDir}/${perlCont} tpage \
			--define qos=short \
			--define cpu=1 \
			--define mem=10000 \
			--define time="05:55:00" \
			--define excludeNode=${excludeNode} \
			--define jobLab=${jobLab} \
			--define stepDir=${stepDir} \
			--define anaDir=${anaDir} \
			--define confFile=${anaDir}/${analysisId}.mvp.master.conf \
			--define analysisId=${analysisId} \
			--define pedigree=${pedigree} \
			--define sample=${sample} \
			--define candigene="${geneDir}/${candidateGenes}" \
			--define casesummToml="${casesummDir}/mvp.workdir.known_extensions.toml" \
			--define settings=${anaDir}/${pipeConf%.conf}.settings.json \
			--define coverage=${anaDir}/${pedigree}/mosdepth/${sample}/${sample}.coverage.metrics \
			--define somalier=${anaDir}/somalier/${analysisId}_inferred.samples.tsv \
			${pipeDir}/templates/casesumm.tt > ${jobCmd}
			JID=$(sbatch --parsable ${jobCmd})
			if [ $? != 0 ]; then echo "ERROR : Cannot submit [${jobCmd}]" >> ${errLog}; exit 1; fi
			echo -e "${jobCmd}\t${JID}" | tee -a ${casesummLog} | tee -a ${jobLog}
		done < <(grep "^${pedigree}\s" ${anaDir}/${analysisId}_samples_rawdata.tsv)
	done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | cut -f 1 | sort -u)
	echo "# INFO - Done!" | tee -a ${casesummLog}
