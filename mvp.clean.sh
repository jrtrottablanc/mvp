touch ${cleanLog}
	
	echo "# INFO - Cleaning MVPGermline pipeline results [${now}] ..." | tee -a ${cleanLog}
	
	echo "# INFO - Step(s) required : [${step}]" | tee -a ${cleanLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${cleanLog}
	
	cat << "EOF"

	██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ 
	██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ 
	██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
	██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║
	╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝
	 ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

	        HEY! You’re about to clean directories.
        	Files may be permanently lost :(

EOF
read -p "Continue? [y/N]: " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi

	# save logs
	echo "# INFO - Saving configuration, sample sheet and log files into analysis folder ..." | tee -a ${cleanLog}
	for ext in conf sampleSheet.tsv launch.log check.log copy.log copyReport.log copyGPAP.log casesumm.log time.log qc.log; do
		if [ -f ${analysisId}.mvp.${ext} ]; then cp -v ${analysisId}.mvp.${ext} ${anaDir}/ | tee -a ${cleanLog}; fi
	done	
	
	# save analysis intermediate
	saveDir="${anaDir}/${analysisId}_Save"
	echo "# INFO - Analysis save folder : [${saveDir}]" | tee -a ${cleanLog}
	mkdir -p ${saveDir}
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
		
		echo -n "# INFO - Saving intermediate files for step [${stepitem}] into analysis save folder ..." | tee -a ${cleanLog}
	
		while read stepName stepSub stepCondition stepOrga stepOutput stepSave stepFnametmp; do
	
			# organism
			if [ "${stepOrga}" != "all" ] && [ "${stepOrga}" != "${organism}" ]; then continue; fi
			
			nSampAna=$(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | wc -l)	
			
			while read pedigree; do
				pedDir="${anaDir}/${pedigree}"
				nSampPed=$(grep -v "^#" ${pedDir}/${pedigree}_samples_rawdata.tsv | wc -l)
				
				while read ped sample app sex bcam gvcf vcf; do
					
					echo -n "." | tee -a ${cleanLog}
				
					stepFile=$(printf "%s" "$stepOutput" \
						| sed -e "s|STEP|$stepName|g" \
							-e "s|ANAID|$analysisId|g" \
						        -e "s|ANA|$anaDir|g" \
						        -e "s|PED|$ped|g" \
						        -e "s|SAMP|$sample|g" \
						        -e "s|SUB|$stepSub|g" \
						        -e "s|APP|$app|g" \
						        -e "s|MANEPREFIX|$manePrefix|g")

					stepDest=$(printf "%s" "$stepSave" \
						| sed -e "s|SAVE|$saveDir|g" \
						        -e "s|PED|$ped|g" \
						        -e "s|SAMP|$sample|g")

					stepFname=$(printf "%s" "$stepFnametmp" \
						| sed -e "s|PED|$ped|g" \
						        -e "s|SAMP|$sample|g")					

					mkdir -p ${stepDest}
					
					if [ ! -f ${stepDest}/${stepFname} ]; then
						condition_ok=false
						case ${stepCondition} in
							no)
								condition_ok=true;;
							nsana)
								[ "${nSampAna}" -gt 1 ] && condition_ok=true;;
							nsped)
								[ "${nSampPed}" -gt 1 ] && condition_ok=true;;
							wgs)
								[ "${app}" = "WGS" ] && condition_ok=true;;
							wes)
								[ "${app}" != "WGS" ] && condition_ok=true;;
							*)
								echo "ERROR : Unknown step condition [${stepCondition}]" | tee -a ${cleanLog};;
						esac

						if $condition_ok; then
							move_or_error
						fi
					fi
						
				done < <(grep "^${pedigree}\s" ${anaDir}/${analysisId}_samples_rawdata.tsv)
			done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | cut -f 1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepsave.conf)
		echo | tee -a ${cleanLog}
	done
	
	# remove analysis dir
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
		
		echo -n "# INFO - Removing analysis directory for step [${stepitem}] ..." | tee -a ${cleanLog}
	
		while read stepName stepOutput; do
			
			nSampAna=$(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | wc -l)	
			
			while read pedigree; do
				pedDir="${anaDir}/${pedigree}"
				nSampPed=$(grep -v "^#" ${pedDir}/${pedigree}_samples_rawdata.tsv | wc -l)
				
				echo -n "." | tee -a ${cleanLog}
				
				stepDir=$(printf "%s" "$stepOutput" \
					| sed -e "s|STEP|$stepName|g" \
        					-e "s|ANA|$anaDir|g" \
        					-e "s|PED|$pedigree|g")

				if [ -d ${stepDir} ]; then
					rm -rf ${stepDir}
				fi
								
			done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | cut -f 1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepclean.conf)
		echo | tee -a ${cleanLog}
	done
	
	echo "# INFO - Done!" | tee -a ${cleanLog}
	
	cp ${analysisId}.mvp.clean.log ${anaDir}/
