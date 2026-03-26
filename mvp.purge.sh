touch ${purgeLog}
	
	echo "# INFO - Purging MVPGermline pipeline results [${now}] ..." | tee -a ${purgeLog}
	
	echo "# INFO - Step(s) required : [${step}]" | tee -a ${purgeLog}

	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${purgeLog}
	
	echo "# INFO - Sample barcode(s) to process : [${barcode}]" | tee -a ${purgeLog}
	
	IFS=',' read -r -a bclist <<< "${barcode}"
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
		
		echo -n "# INFO - Purging analysis directory for step [${stepitem}] ..." | tee -a ${purgeLog}

		while read stepName stepOutput; do
				
			while read pedigree; do
				
				while read ped sample app sex bcam gvcf vcf; do
					
					if [[ " ${bclist[*]} " =~ " all " ||  " ${bclist[*]} " =~ " ${sample} " ]]; then
						
						echo -n "." | tee -a ${purgeLog}
					
						stepDir=$(printf "%s" "$stepOutput" \
                                        		| sed -e "s|STEP|$stepName|g" \
                                                		-e "s|ANA|$anaDir|g" \
                                                		-e "s|PED|$pedigree|g")
						
						if [ -d ${stepDir}/${sample} ]; then rm -rf ${stepDir}/${sample}; fi
					
					fi
					
				done < <(grep "^${pedigree}\s" ${anaDir}/${analysisId}_samples_rawdata.tsv)
			done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | cut -f 1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepclean.conf)
		echo | tee -a ${purgeLog}
	done
	
	echo "# INFO - Done!" | tee -a ${purgeLog}