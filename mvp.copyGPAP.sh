touch ${copyGPAPLog}
	
	echo "# INFO - Copying MVPGermline pipeline GPAP results [${now}] ..." | tee -a ${copyGPAPLog}

	echo "# INFO - Step(s) required : [${step}]" | tee -a ${copyGPAPLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${copyGPAPLog}
	
	cnvDir="/scratch_isilon/groups/dat/data/GPAP/CNV"
	echo "# INFO - GPAP CNV folder : [${cnvDir}]" | tee -a ${copyGPAPLog}
	
	igvDir="/scratch_isilon/groups/dat/data/GPAP/igvCRAM"
	echo "# INFO - GPAP igvCRAM folder : [${igvDir}]" | tee -a ${copyGPAPLog}
	
	trackDir="/scratch_isilon/groups/dat/data/GPAP/IMPACT_tracks"
	echo "# INFO - GPAP track folder : [${trackDir}]" | tee -a ${copyGPAPLog}
	
	# Copy analysis output
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
		
		echo -n "# INFO - Copying GPAP OUTPUTs for step [${stepitem}] ..." | tee -a ${copyGPAPLog}
		
		while read stepName stepSub stepCondition stepOrga stepOutput stepResults; do
			
			# organism
			if [ "${stepOrga}" != "all" ] && [ "${stepOrga}" != "${organism}" ]; then continue; fi
			
			while read -r pedigree; do
				pedDir="${anaDir}/${pedigree}"

				grep "^${pedigree}\s" "$anaDir/${analysisId}_samples_rawdata.tsv" |
				while read -r ped sample app sex bcam gvcf vcf; do

					echo -n "." | tee -a "${copyGPAPLog}"

					# FREEC suffix
					if [ "$app" = "WGS" ]; then
						freecsuf="20000"
					else
						freecsuf="HyperExome"  # TODO: replace with generic name
					fi

					subproject="$analysisId"
					project="${analysisId%%_*}"

					# Resolve stepFile
					stepFile=$(printf "%s" "$stepOutput" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANA|$anaDir|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|SUB|$stepSub|g" \
							  -e "s|APP|$app|g")

					# Resolve final destination
					stepDest=$(printf "%s" "$stepResults" \
						| sed -e "s|IGVDEST|$igvDir|g" \
							  -e "s|CNVDEST|$cnvDir|g" \
							  -e "s|TRACKDEST|$trackDir|g" \
							  -e "s|SUBPROJECT|$subproject|g" \
							  -e "s|PROJECT|$project|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|FREECSUF|$freecsuf|g")

					mkdir -p "$(dirname "$stepDest")"

					case "$stepCondition" in
						no)
							copy_or_touch "$stepFile" "$stepDest" ;;
						wgs)
							[ "$app" = "WGS" ] && copy_or_touch "$stepFile" "$stepDest" ;;
						wes)
							[ "$app" != "WGS" ] && copy_or_touch "$stepFile" "$stepDest" ;;
						wesfreec)
							[ "$app" != "WGS" ] && copy_or_touch "$stepFile" "$stepDest" ;;
						wgsfreectrack)
							if [ "$var2trackFreec" != "NA" ] && [ "$app" = "WGS" ]; then
								copy_or_touch "$stepFile" "$stepDest"
							fi ;;
						wesfreectrack)
							if [ "$var2trackFreec" != "NA" ] && [ "$app" != "WGS" ]; then
								copy_or_touch "$stepFile" "$stepDest"
							fi ;;
						nvarsmvcf)
							if [ "$var2trackManta" != "NA" ] && \
							   has_cntvar_gt0 "${stepFile%.full.vcf.gz}"; then
								copy_or_touch "$stepFile" "$stepDest"
							fi ;;
						nvarsmtbi)
							if [ "$var2trackManta" != "NA" ] && \
							   has_cntvar_gt0 "${stepFile%.full.vcf.gz.tbi}"; then
								copy_or_touch "$stepFile" "$stepDest"
							fi ;;
						*)
							echo "ERROR : Unknown step condition [$stepCondition]" >&2 ;;
					esac
				done
			done < <(grep -v "^#" "$anaDir/${analysisId}_samples_rawdata.tsv" | cut -f1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepgpap.conf)
		echo | tee -a ${copyGPAPLog}
	done
	
	echo "# INFO - Done!" | tee -a ${copyGPAPLog}