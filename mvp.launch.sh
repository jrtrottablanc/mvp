	touch ${launchLog}

#georgia='no'
	
	echo "# INFO - Launching MVPGermline pipeline [${now}] ..." | tee -a ${launchLog}
	
	echo "# INFO - Checking templates [${pipeDir}/templates_md5sum.txt] ..." | tee -a ${launchLog}
	if ! md5sum --quiet -c ${pipeDir}/templates_md5sum.txt; then
	    echo "ERROR : Templates md5sum do not match" | tee -a ${launchLog}
	    exit 1
	fi
	
	echo "# INFO - Step(s) required : [${step}]" | tee -a ${launchLog}
	
	echo "# INFO - Getting user configuration [$uconf] ..." | tee -a ${launchLog}
	
	echo "# INFO - Getting pipeline configuration [${confDir}/${pipeConf}] ..." | tee -a ${launchLog}
	
	echo "# INFO - Creating analysis folder [${anaDir}] ..." | tee -a ${launchLog}
	mkdir -p ${anaDir}
	cd ${anaDir}

	#--------------#
	# sample sheet #
	#--------------#
	echo "# INFO - Creating analysis sample sheet [${anaDir}/${analysisId}_samples_info.tsv] ..." | tee -a ${launchLog}
	#~ if [ ! -f ${anaDir}/${analysisId}_samples_info.tsv ]; then
		if [ "${cnagProd}" = "yes" ]; then	
			limsSubproj=$(${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | cut -d ";" -f 2 | sort -u)
			if [ "${limsSubproj}" = "" ]; then
				echo "ERROR : cnagProd 'yes' but unrecognized LIMS subproject [${analysisId}]"
				exit 1
			else
				echo -e "#pedigree\tbarcode\tsampleName\tsex\tsampleStatus\tsubproject\tapp\tmotherId\tfatherId\tbamcram\tgvcf\tvcf" > ${analysisId}_samples_info.head.tsv
				if [ "${georgia}" = "no" ]; then
					${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | \
					awk -F";" '{if($15=="WG-Seq"){APP="WGS"}else{APP=$16};gsub(/ /,"_",APP); if($19=="None"||$19==""){PEDID=$5}else{PEDID=$19}; if($28=="Affected"){PHENO="2"}else if($28=="Unaffected"){PHENO="1"}else{PHENO="-9"}; if($24=="None"){MOTHER="-9"}else{MOTHER=$24};if($25=="None"){FATHER="-9"}else{FATHER=$25};print PEDID,$5,$4,PHENO,$2,APP,MOTHER,FATHER,"/scratch_isilon/groups/pbt/jcamps/mappings/samples/"$1"/"$2"/"$5"/"$5".bqsr.bam","/scratch_isilon/groups/pbt/jcamps/mappings/samples/"$1"/"$2"/"$5"/"$5".bqsr.bam.CHRNAME.g.vcf.gz","NA"}' OFS="\t" | \
					sort -u > ${analysisId}_samples_info.limsq.tsv
				else
					${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | \
					awk -F";" '{if($15=="WG-Seq"){APP="WGS"}else{APP=$16};gsub(/ /,"_",APP); if($19=="None"||$19==""){PEDID=$5}else{PEDID=$19}; if($28=="Affected"){PHENO="2"}else if($28=="Unaffected"){PHENO="1"}else{PHENO="-9"}; if($24=="None"){MOTHER="-9"}else{MOTHER=$24};if($25=="None"){FATHER="-9"}else{FATHER=$25};print PEDID,$5,$4,PHENO,$2,APP,MOTHER,FATHER,"/scratch_isilon/groups/dat/gkesisoglou/analysis/kapaconsensus_no_consensus/"$2"/results/bqsr/"$5"/"$5"_apply_bqsr.bam","NA","NA"}' OFS="\t" | \
					sort -u > ${analysisId}_samples_info.limsq.tsv		
				fi
				
				while read pedigree sample sampleName sampleStatus subproject app motherId fatherId BCAM GVCF VCF; do
					while read sp bc colSex pcrStr covStr; do
						covSex=0; \
						if (( $(echo "$covStr >= 0.2" | bc -l) )); then covSex=1; fi
						if (( $(echo "$covStr < 0.2" | bc -l) )); then covSex=2; fi
					done < <(${funcDir}/sexBySamp.sh -s $sample -p $subproject | grep -v "^#")
					echo -e "$pedigree\t$sample\t$sampleName\t$covSex\t$sampleStatus\t$subproject\t$app\t$motherId\t$fatherId\t$BCAM\t$GVCF\t$VCF"
				done < ${analysisId}_samples_info.limsq.tsv > ${analysisId}_samples_info.tmp.tsv
				cat ${analysisId}_samples_info.head.tsv ${analysisId}_samples_info.tmp.tsv > ${analysisId}_samples_info.tsv
				rm ${analysisId}_samples_info.head.tsv ${analysisId}_samples_info.limsq.tsv ${analysisId}_samples_info.tmp.tsv
			fi
		else
			cat ${realSampleSheet} > ${analysisId}_samples_info.tsv
		fi
	#~ fi
	
	#--------------#
	# sheet check  #
	#--------------#
	echo "# INFO - Checking sample sheet information [${anaDir}/${analysisId}_samples_info.tsv] ..." | tee -a ${launchLog}
	expected_fields=("#pedigree" "barcode" "sampleName" "sex" "sampleStatus" "subproject" "app" "motherId" "fatherId" "bamcram" "gvcf" "vcf")
	line_number=0
 	while IFS= read -r line || [ -n "${line}" ]; do
		((line_number++))
		IFS=$'\t' read -r -a fields <<< "${line}"
		if [ "${line_number}" -eq 1 ]; then
			if [ "${#fields[@]}" -ne "${#expected_fields[@]}" ]; then
				echo "ERROR : Sample sheet header does not have the expected number of fields: expected [${#expected_fields[@]}], got [${#fields[@]}]"
				exit 1
			fi
			for i in "${!expected_fields[@]}"; do
				if [ "${fields[i]}" != "${expected_fields[i]}" ]; then
					echo "ERROR : Header field mismatch at position $((i+1)): expected '${expected_fields[i]}', found '${fields[i]}'"
					exit 1
				fi
			done
		else
			if [ "${#fields[@]}" -ne ${#expected_fields[@]} ]; then
				echo "ERROR : Line $line_number has missing or extra fields"
				exit 1
			fi
		fi
	done < ${analysisId}_samples_info.tsv
	
	#--------------#
	# ROI check    #
	#--------------#
	while read app; do
		echo "# INFO - Checking pipeline ROI configuration for app [${app}] [${confDir}/${pipeConf%.conf}_ROI_${app}.conf] ..." | tee -a ${launchLog}
		if [ -f ${confDir}/${pipeConf%.conf}_ROI_${app}.conf ]; then
			source ${confDir}/${pipeConf%.conf}_ROI_${app}.conf
			if [ "${app}" != "WGS" ]; then
				check_param "${roiBed}" "roiBed parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				check_file "roiBed" "${roiBed}"
				check_param "${bedPadding}" "bedPadding parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [[ " ${stepuser[*]} " =~ " exdepth " ]]; then
					check_param "${exdepthRef}" "exdepthRef parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
					check_param "${exdepthPath}" "exdepthPath parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
					mkdir -p ${exdepthPath}
					check_directory "exdepthPath" "${exdepthPath}"
				fi
			fi
			if [[ " ${stepuser[*]} " =~ " freec " ]]; then	
				check_param "${freecMaleBase}" "freecMaleBase parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecMaleBase}" != "NA" ]; then check_file "freecMaleBase" "${freecMaleBase}"; fi
				check_param "${freecFemaleBase}" "freecFemaleBase parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecFemaleBase}" != "NA" ]; then check_file "freecFemaleBase" "${freecFemaleBase}"; fi
				check_param "${freecChrLen}" "freecChrLen parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecChrLen}" != "NA" ]; then check_file "freecChrLen" "${freecChrLen}"; fi
				check_param "${freecPloidy}" "freecPloidy parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				check_param "${freecChrDir}" "freecChrDir parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecChrDir}" != "NA" ]; then check_directory "freecChrDir" "${freecChrDir}"; fi
				check_param "${freecMappa}" "freecMappa parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecMappa}" != "NA" ]; then check_file "freecMappa" "${freecMappa}"; fi
				check_param "${freecSnpfile}" "freecSnpfile parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
				if [ "${freecSnpfile}" != "NA" ]; then check_file "freecSnpfile" "${freecSnpfile}"; fi
                check_param "${freecMakepileup}" "freecMakepileup parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
                if [ "${freecMakepileup}" != "NA" ]; then check_file "freecMakepileup" "${freecMakepileup}"; fi
				if [ "${app}" != "WGS" ]; then
                check_param "${freecBed}" "freecBed parameter is missing into pipeline ROI configuration file [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]"
                if [ "${freecBed}" != "NA" ]; then check_file "freecBed" "${freecBed}"; fi
				fi
			fi
		else
			echo "ERROR - No ROI configuration defined for [${app}], expect [${confDir}/${pipeConf%.conf}_ROI_${app}.conf]" | tee -a ${launchLog}
			exit 1
		fi
	done < <(grep -v "^#" ${analysisId}_samples_info.tsv | cut -f 7 | sort -u)
	
	cat "${analysisId}_samples_info.tsv" | tee -a ${launchLog}	
	
	read -p "Launch the pipeline using this sample sheet? (Y|n)" -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
	
	#--------------#
	# settings     #
	#--------------#
	echo "# INFO - Copying pipeline settings [${confDir}/${pipeConf%.conf}.settings.json] ..." | tee -a ${launchLog}
	if [ -f ${confDir}/${pipeConf%.conf}.settings.json ]; then
		cp ${confDir}/${pipeConf%.conf}.settings.json ${anaDir}/
	else
		echo "ERROR - Pipeline settings file is missing. Expect [${confDir}/${pipeConf%.conf}.settings.json]" | tee -a ${launchLog}
		exit 1
	fi
	
	#--------------#
	# rawdata      #
	#--------------#
	echo "# INFO - Getting rawdata ..." | tee -a ${launchLog}
	if [ ! -f ${analysisId}_samples_rawdata.tsv ]; then
		echo -e "#pedigree\tsample\tapp\tsex\tbamcram\tgvcf\tvcf" > ${analysisId}_samples_rawdata.tsv
	fi
	while read pedigree sample sampleName sex sampleStatus subproject app motherId fatherId BCAM GVCF VCF; do
		BCAMname=$(basename "${BCAM}")
		BCAMext="${BCAMname##*.}"
		BCAMidx=$(echo $BCAMext | sed 's/m/i/')
		echo "${anaDir}/${pedigree}/rawdata/${sample}" | tee -a ${launchLog}
		if [ ! -d ${anaDir}/${pedigree}/rawdata/${sample} ]; then
			mkdir -p ${anaDir}/${pedigree}/rawdata/${sample}
			
			# bamcram
			if [ "${BCAM}" != "NA" ]; then
				if [ -f "${BCAM}" ]; then
					ln -s ${BCAM} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMext}
				else
					echo "ERROR : Input BAM/CRAM is not a regular file [${BCAM}]" | tee -a ${launchLog}
					exit 1
				fi

				if [ -f ${BCAM}.${BCAMidx} ]; then
					ln -s ${BCAM}.${BCAMidx} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMidx}
				elif [ -f ${BCAM%.bam}.${BCAMidx} ]; then
					ln -s ${BCAM%.bam}.${BCAMidx} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMidx}
				elif [ -f ${BCAM%.cram}.${BCAMidx} ]; then
					ln -s ${BCAM%.cram}.${BCAMidx} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMidx}
				else
					echo "ERROR : Input BAM/CRAM is not indexed [${BAM}]" | tee -a ${launchLog}
					exit 1
				fi
				ln -s ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMidx} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMext}.${BCAMidx}
				BCAMsheet="${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${BCAMext}"
			else
				BCAMsheet="NA"
			fi
	
			for chr in ${chrList}; do
				# gvcf
				if [ "${GVCF}" != "NA" ]; then
					chrGVCF=$(echo ${GVCF} | sed "s/CHRNAME/$chr/")
					if [ -f ${chrGVCF} ]; then
						ln -s ${chrGVCF} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${chr}.g.vcf.gz
						if [ -f ${chrGVCF}.tbi ]; then
							ln -s ${chrGVCF}.tbi ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${chr}.g.vcf.gz.tbi
						else
							echo "ERROR : Input gVCF is not indexed [${chrGVCF}]" | tee -a ${launchLog}
							exit 1
						fi
						GVCFsheet="${anaDir}/${pedigree}/rawdata/${sample}/${sample}.CHRNAME.g.vcf.gz"
					else
						echo "ERROR : Input gVCF for chr [${chr}] is not a regular file [${chrGVCF}]" | tee -a ${launchLog}
						exit 1
					fi
				else
					GVCFsheet="NA"
				fi
				# vcf
				if [ "${VCF}" != "NA" ]; then
					chrVCF=$(echo ${VCF} | sed "s/CHRNAME/$chr/")
					if [ -f ${chrVCF} ]; then
						ln -s ${chrVCF} ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${chr}.g.geno.vcf.gz
						if [ -f ${chrVCF}.tbi ]; then
							ln -s ${chrVCF}.tbi ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.${chr}.g.geno.vcf.gz.tbi
						else
							echo "ERROR : Input VCF is not indexed [${chrVCF}]" | tee -a ${launchLog}
							exit 1
						fi
						VCFsheet="${anaDir}/${pedigree}/rawdata/${sample}/${sample}.CHRNAME.g.geno.vcf.gz"
					else
						echo "ERROR : Input VCF for chr [${chr}] is not a regular file [${chrVCF}]" | tee -a ${launchLog}
						exit 1
					fi
				else
					VCFsheet="NA"
				fi
			done
			
			echo -e "$pedigree\t$sample\t$app\t$sex\t${BCAMsheet}\t${GVCFsheet}\t${VCFsheet}" >> ${analysisId}_samples_rawdata.tsv
		fi
		
	done < <(grep -v "^#" ${analysisId}_samples_info.tsv)
	
	#--------------#
	# bam check    #
	#--------------#
	echo "# INFO - Checking files integrity ..." | tee -a ${launchLog}
	while read pedigree sample app sex BCAM GVCF VCF; do
		# bamcram
		if [ "${BCAM}" != "NA" ]; then
			echo -ne "${BCAM} ... " | tee -a ${launchLog}
			apptainer run --no-home --bind ${bindDir} ${contDir}/${samtoolsCont} samtools quickcheck -v ${BCAM}
			if [ $? != 0 ]; then echo -e "FAILED"; exit 1; fi | tee -a ${launchLog}
			echo "OK!" | tee -a ${launchLog}
		fi		
	done < <(grep -v "^#" ${analysisId}_samples_rawdata.tsv)

	#--------------#
	# report sheet #
	#--------------#
	limsSubproj=$(${funcDir}/limsq_nhopt -nH -sp ${analysisId} -lanepf fail,waiting,under_review | cut -d ";" -f 2 | sort -u)
	if [ "${limsSubproj}" != "" ]; then
		echo "# INFO - Generating sample sheet for production report ..." | tee -a ${launchLog}
		while read pedigree sample app sex BCAM GVCF VCF; do
			if [ ! -f ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf ]; then
				mysqlOpt=" -h lims.internal.cnag.eu -u lims_ro -p4eCrrEG8 -D lims -B --column-names=0 -e "
				sampleName=$(mysql ${mysqlOpt} "SELECT name FROM sequencing_sample WHERE barcode = '${sample}'")
				RstartDate=$(mysql ${mysqlOpt} "SELECT DATE_FORMAT(data_transfer_ready_date,\"%d/%m/%Y\") FROM sequencing_subproject WHERE sequencing_subproject.subproject_name = '${analysisId}'")
				RpiEmail=$(mysql ${mysqlOpt} "SELECT sequencing_contact.email FROM sequencing_contact JOIN sequencing_subprojectcontactslist ON sequencing_subprojectcontactslist.contact_id = sequencing_contact.id JOIN sequencing_subproject ON sequencing_subproject.id = sequencing_subprojectcontactslist.subproject_id WHERE sequencing_subproject.subproject_name = '${analysisId}' AND sequencing_subprojectcontactslist.pi = 1 LIMIT 0,1")
				RpiName=$(mysql ${mysqlOpt} "SELECT sequencing_contact.first_name, sequencing_contact.last_name FROM sequencing_contact JOIN sequencing_subprojectcontactslist ON sequencing_subprojectcontactslist.contact_id = sequencing_contact.id JOIN sequencing_subproject ON sequencing_subproject.id = sequencing_subprojectcontactslist.subproject_id WHERE sequencing_subproject.subproject_name = '${analysisId}' AND sequencing_subprojectcontactslist.pi = 1 LIMIT 0,1")
				limsEnac=$(mysql ${mysqlOpt} "SELECT enac_accredited FROM sequencing_sop JOIN sequencing_library ON sequencing_library.sop_id = sequencing_sop.id JOIN sequencing_librarysubproject ON sequencing_librarysubproject.library_id = sequencing_library.id JOIN sequencing_subproject ON sequencing_subproject.id = sequencing_librarysubproject.subproject_id WHERE sequencing_subproject.subproject_name = '${analysisId}' LIMIT 0,1")
				if [ "$limsEnac" = "1" ]; then RisEnac='T'; else RisEnac='F'; fi
				if [ "${app}" = "WGS" ]; then RappReport="wgs" ; else RappReport="exome" ; fi
				RappStats=$(mysql ${mysqlOpt} "SELECT sequencing_application.name FROM sequencing_application JOIN sequencing_subproject ON sequencing_subproject.application_id = sequencing_application.id WHERE sequencing_subproject.subproject_name = '${analysisId}'")
				echo "analysisId=\"${analysisId}\"" > ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "sampleName=\"${sampleName}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RstartDate=\"${RstartDate}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RpiEmail=\"${RpiEmail}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RpiName=\"${RpiName}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RisEnac=\"${RisEnac}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RappReport=\"${RappReport}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "RappStats=\"${RappStats}\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
				echo "mvpConfig=\"${anaDir}/${pipeConf%.conf}.settings.json\"" >> ${anaDir}/${pedigree}/rawdata/${sample}/${sample}.reportSheet.conf
			fi
		done < <(grep -v "^#" ${analysisId}_samples_rawdata.tsv)
	else
		echo "# INFO - analysisId [${analysisId}] does not correspond to any LIMS subproject, report is not available" | tee -a ${launchLog}
	fi

	#--------------#
	# master conf  #
	#--------------#
	cat ${confDir}/path.conf \
	${confDir}/templates.conf \
	${confDir}/containers.conf \
	${confDir}/ressources.conf \
	${confDir}/${pipeConf} \
	$uconf | grep -v "^#" > ${anaDir}/${analysisId}.mvp.master.conf

	#--------------#
	# submit mvp   #
	#--------------#
	jobLab="${analysisId}.mvp"
	jobCmd="${anaDir}/${jobLab}.cmd"
	jobLog="${anaDir}/${jobLab}.jobID.log"
	errLog="${anaDir}/ERROR.log"
	echo "# INFO - Submitting mvp ..." | tee -a ${launchLog}
	apptainer run --no-home --bind ${bindDir} ${contDir}/${perlCont} tpage \
	--define qos=short \
	--define cpu=1 \
	--define mem=8000 \
	--define time="05:55:00" \
	--define excludeNode=${excludeNode} \
	--define jobLab=${jobLab} \
	--define anaDir=${anaDir} \
	--define confFile=${anaDir}/${analysisId}.mvp.master.conf \
	--define analysisId=${analysisId} \
	--define step=${step} \
	${pipeDir}/mvp.tt > ${jobCmd}
	JID=$(sbatch --parsable ${jobCmd})
	if [ $? != 0 ]; then echo "ERROR : Cannot submit [${jobCmd}]" >> ${errLog}; exit 1; fi
	echo -e "${jobCmd}\t${JID}" | tee -a ${launchLog} | tee -a ${jobLog}
	
	echo "# INFO - Done!" | tee -a ${launchLog}
