touch ${qcLog}
	
	echo "# INFO - Checking MVPGermline pipeline QC metrics [${now}] ..." | tee -a ${qcLog}
		
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${qcLog}
	
	# LIMS link
	echo "# INFO - Generating LIMS QC link ..." | tee -a ${qcLog}
	limsSubproj=$(${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | cut -d ";" -f 2 | sort -u)
	if [ "${limsSubproj}" != "" ]; then
		mysqlOpt=" -h lims.internal.cnag.eu -u lims_ro -p4eCrrEG8 -D lims -B --column-names=0 -e "
		subprojID=$(mysql ${mysqlOpt} "SELECT id FROM sequencing_subproject WHERE subproject_name = '${analysisId}'")
		echo "https://lims.cnag.cat/lims/subproject_sample_details/${subprojID}/" | tee -a ${qcLog}
	else
		echo "# INFO - analysisId [${analysisId}] does not correspond to any LIMS subproject, LIMS QC link is not available" | tee -a ${qcLog}
	fi
	
	# somalier link
	echo "# INFO - Getting somalier report ..." | tee -a ${qcLog}
	if [ -f ${anaDir}/somalier/${analysisId}_inferred.html ]; then
		echo "${anaDir}/somalier/${analysisId}_inferred.html" | tee -a ${qcLog}
	else
		echo "# INFO - Somalier inferred report is not available, expected [${anaDir}/somalier/${analysisId}_inferred.html]" | tee -a ${qcLog}
	fi
	if [ -f ${anaDir}/somalier/${analysisId}_ancestry.somalier-ancestry.html ]; then
		echo "${anaDir}/somalier/${analysisId}_ancestry.somalier-ancestry.html" | tee -a ${qcLog}
	else
		echo "# INFO - Somalier ancestry report is not available, expected [${anaDir}/somalier/${analysisId}_ancestry.somalier-ancestry.html]" | tee -a ${qcLog}
	fi
	
	# pipeline metrics
	while read pedigree sample sampleName sex sampleStatus subproject app motherId fatherId BCAM GVCF VCF; do
		
		sexstr='male'
		if [ "${sex}" = "2" ]; then sexstr='female'; fi
		
		echo "# INFO - Generating pipeline QC metrics for sample [${sample}] ..." | tee -a ${qcLog}
		
		# coverage
		echo "# INFO - Effective coverage metrics ..." | tee -a ${qcLog}
		if [ -f ${anaDir}/${pedigree}/mosdepth/${sample}/${sample}.coverage.metrics ]; then
			grep -v "^##" ${anaDir}/${pedigree}/mosdepth/${sample}/${sample}.coverage.metrics | tee -a ${qcLog}
		else
			echo "# INFO - Coverage metrics are not available, expected [${anaDir}/${pedigree}/mosdepth/${sample}/${sample}.coverage.metrics]" | tee -a ${qcLog}
		fi
		
		# sex
		echo "# INFO - Sex metrics ..." | tee -a ${qcLog}
		colSex='NA'
		pcrSex='NA'
		covSex='NA'
		limsSubproj=$(${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | cut -d ";" -f 2 | sort -u)
		if [ "${limsSubproj}" != "" ]; then
			while read sp bc colStr pcrStr covStr; do
				colSex=${colStr}
				pcrSex=0
				if [ "$pcrStr" = "Male" ]; then pcrSex=1; fi
				if [ "$pcrStr" = "Female" ]; then pcrSex=2; fi
				covSex=0
				if (( $(echo "$covStr >= 0.2" | bc -l) )); then covSex=1; fi
				if (( $(echo "$covStr < 0.2" | bc -l) )); then covSex=2; fi
			done < <(${funcDir}/sexBySamp.sh -s ${sample} -p ${subproject} | grep -v "^#")
		fi
		somSex='NA'
		if [ -f ${anaDir}/somalier/${analysisId}_inferred.samples.tsv ]; then
			somSex=$(cat ${anaDir}/somalier/${analysisId}_inferred.samples.tsv | awk -v sample=${sample} '{if($2==sample){print $5}}')
		fi
		echo -e "#sample\tsampleSheetSex\tcollabReportedSex\tpcrSex\tcovratioSex\tsomalierSex" | tee -a ${qcLog}
		echo -e "${sample}\tinf_${sex}\tcol_${colSex}\tpcr_${pcrSex}\tcov_${covSex}\tsom_${somSex}" | tee -a ${qcLog}
		
		# relatedness
		echo "# INFO - Somalier relatedness metrics ..." | tee -a ${qcLog}
		fatherped=$(cat ${anaDir}/${pedigree}/${pedigree}_samples_info.ped | awk -v sample=${sample} '{if($2==sample){print $3}}')
		motherped=$(cat ${anaDir}/${pedigree}/${pedigree}_samples_info.ped | awk -v sample=${sample} '{if($2==sample){print $4}}')
		fathersomrel="NA\tNA"
		if [ "${fatherped}" != "-9" ]; then
			fathersomrel=$(cat ${anaDir}/${pedigree}/somalier/${pedigree}_inferred.pairs.tsv | awk -v sample=${sample} -v fatherped=${fatherped} '{if($1==sample && $2==fatherped){print $3"\t"$17}}')
		fi
		mothersomrel="NA\tNA"
		if [ "${motherped}" != "-9" ]; then
			mothersomrel=$(cat ${anaDir}/${pedigree}/somalier/${pedigree}_inferred.pairs.tsv | awk -v sample=${sample} -v motherped=${motherped} '{if($1==sample && $2==motherped){print $3"\t"$17}}')
		fi
		echo -e "#sample\tfatherPed\tfatherRelatedness\tmotherPed\tmotherRelatedness" | tee -a ${qcLog}
		echo -e "${sample}\t${fatherped}\t${fathersomrel}\t${motherped}\t${mothersomrel}" | tee -a ${qcLog}
	
		# vcfstats
		echo "# INFO - Shortvariants VCF metrics ..." | tee -a ${qcLog}
		if [ -f ${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv ]; then
			echo -e "#sample\tchr\tcntSNV\tQCminSNV\tQCmaxSNV\tcntINDEL\tQCminINDEL\tQCmaxINDEL" | tee -a ${qcLog}
			for chr in ${chrList}; do \
				cntsnp='NA'
				cntindel='NA'
				vcfstats="${anaDir}/${pedigree}/hapcallgenonorm/${sample}/${sample}.${chr}.g.geno.norm.vcf.gz.stats"
				if [ -f ${vcfstats} ]; then
					cntsnp=$(grep -v "^#" ${vcfstats} | cut -f 3)
					cntindel=$(grep -v "^#" ${vcfstats} | cut -f 4)
				fi
				qccntsnp=$(grep "^${chr}\s" ${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv | cut -f 2)
				qcdevsnp=$(grep "^${chr}\s" ${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv | cut -f 3)
				qcminsnp=$(echo -e "${qccntsnp}\t${qcdevsnp}" | awk '{print $1-($2*1.5)}')
				qcmaxsnp=$(echo -e "${qccntsnp}\t${qcdevsnp}" | awk '{print $1+($2*1.5)}')
				qccntindel=$(grep "^${chr}\s" ${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv | cut -f 4)
				qcdevindel=$(grep "^${chr}\s" ${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv | cut -f 5)
				qcminindel=$(echo -e "${qccntindel}\t${qcdevindel}" | awk '{print $1-($2*1.5)}')
				qcmaxindel=$(echo -e "${qccntindel}\t${qcdevindel}" | awk '{print $1+($2*1.5)}')
				
				echo -e "${sample}\t${chr}\t${cntsnp}\t${qcminsnp}\t${qcmaxsnp}\t${cntindel}\t${qcminindel}\t${qcmaxindel}" | tee -a ${qcLog}
			done
		else
			echo "# INFO - Baseline for VCF metrics comparison is not available, expected [${qcbaselineDir}/${pipeConf%.conf}_ROI_${app}.${sexstr}.singshortvar.qcbaseline.tsv]" | tee -a ${qcLog}
		fi
		
	done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_info.tsv)

	echo "# INFO - Done!" | tee -a ${qcLog}