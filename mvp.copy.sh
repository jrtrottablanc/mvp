touch ${copyLog}
	
	echo "# INFO - Copying MVPGermline pipeline results [${now}] ..." | tee -a ${copyLog}
	
	echo "# INFO - Step(s) required : [${step}]" | tee -a ${copyLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${copyLog}
	
	resDir="${anaDir}/${analysisId}_Results/${dateResults}"
	echo "# INFO - Analysis results folder : [${resDir}]" | tee -a ${copyLog}
	mkdir -p ${resDir}
	
	echo "# INFO - Copying settings and legend ..." | tee -a ${copyLog}
	# settings
	cp ${anaDir}/${pipeConf%.conf}.settings.json ${resDir}/
	# legend
	cp /scratch_isilon/groups/dat/projects/INS-098_revA_Variant_Calling_Legend.pdf ${resDir}/
	# candidates genes
	mkdir -p ${resDir}/CandidateGenes
	cp ${geneDir}/${candidateGenes} ${resDir}/CandidateGenes/
	while read input tag; do \
		cp ${geneDir}/$input ${resDir}/CandidateGenes/
	done < ${geneDir}/${candidateGenes}
	
	# documentation
	mysqlOpt=" -h lims.internal.cnag.eu -u lims_ro -p4eCrrEG8 -D lims -B --column-names=0 -e "
	app=$(grep -v "^#" ${anaDir}/${analysisId}_samples_info.tsv | cut -f 7 | sort -u)
	mvpdoc="${pipeDir}/CNAG_MVP_pipeline_GRCh38_v5_WGS.pdf"
	if [ "$app" = "WGS" ]; then cp ${mvpdoc} ${resDir}/.; fi
	
	# Copy analysis output
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
	
		echo -n "# INFO - Copying OUTPUTs for step [${stepitem}] ..." | tee -a ${copyLog}
	
		while read stepName stepSub stepCondition stepOrga stepOutput stepResults stepLogs; do
			
			# organism
			if [ "${stepOrga}" != "all" ] && [ "${stepOrga}" != "${organism}" ]; then continue; fi
			
			# do not copy
			if [ "${stepResults}" = "NO" ]; then continue; fi
			
			nSampAna=$(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | wc -l)	
			
			while read -r pedigree; do
				pedDir="${anaDir}/${pedigree}"
				nSampPed=$(grep -vc "^#" "$pedDir/${pedigree}_samples_rawdata.tsv")

				grep "^${pedigree}\s" "$anaDir/${analysisId}_samples_rawdata.tsv" |
				while read -r ped sample app sex bcam gvcf vcf; do

					echo -n "." | tee -a "${copyLog}"

					# Dynamic paths (grouped substitutions)
					stepFile=$(printf "%s" "$stepOutput" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANAID|$analysisId|g" \
							  -e "s|ANA|$anaDir|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|SUB|$stepSub|g" \
							  -e "s|APP|$app|g" \
							  -e "s|MANEPREFIX|$manePrefix|g")

					stepFileName=$(basename "$stepFile")

					stepDest=$(printf "%s" "$stepResults" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANARES|$resDir|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g")

					stepLog=$(printf "%s" "$stepLogs" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANAID|$analysisId|g" \
							  -e "s|ANA|$anaDir|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|SUB|$stepSub|g" \
							  -e "s|APP|$app|g")

					mkdir -p "$stepDest"

					case "$stepCondition" in
						no)
							copy_or_log "$stepFile" "$stepDest" "$stepFileName" ;;
						nsana)
							if [ "$nSampAna" -gt 1 ]; then
								copy_or_log "$stepFile" "$stepDest" "$stepFileName"
							elif [ "$stepLog" != "nan" ]; then
								cp "$stepLog" "$stepDest/expectedNA.log"
							fi ;;
						nsped)
							if [ "$nSampPed" -gt 1 ]; then
								copy_or_log "$stepFile" "$stepDest" "$stepFileName"
							elif [ "$stepLog" != "nan" ]; then
								cp "$stepLog" "$stepDest/expectedNA.log"
							fi ;;
						prod)
							limsSubproj=$($funcDir/limsq_nhopt -nH -sp "$analysisId" -lanepf fail,waiting,under_review | cut -d ";" -f2 | sort -u)
							if [ -n "$limsSubproj" ]; then
								copy_or_log $stepFile "$stepDest" "$stepFileName"
							elif [ "$stepLog" != "nan" ]; then
								cp "$stepLog" "$stepDest/expectedNA.log"
							fi ;;
						nvarssxls)
							check_cntvar_copy "${stepFile%.full.xlsx}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 1000000 le ;;
						nvarsstsv)
							check_cntvar_copy "${stepFile%.full.tsv.gz}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 0 ge ;;
						nvarmthtml)
							check_cntvar_copy "${stepFile%.html}.vcf.gz.cntvar" "$stepFile" "$stepDest" "$stepFileName" 0 gt ;;
						nvarsmvcf)
							[ "$var2trackManta" != "NA" ] &&
							check_cntvar_copy "${stepFile%.full.vcf.gz}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 0 gt ;;
						nvarsmtbi)
							[ "$var2trackManta" != "NA" ] &&
							check_cntvar_copy "${stepFile%.full.vcf.gz.tbi}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 0 gt ;;
						wgs)
							if [ "$app" = "WGS" ]; then
								copy_or_log "$stepFile" "$stepDest" "$stepFileName"
							elif [ "$stepLog" != "nan" ]; then
								cp "$stepLog" "$stepDest/expectedNA.log"
							fi ;;
						wes)
							if [ "$app" != "WGS" ]; then
								copy_or_log "$stepFile" "$stepDest" "$stepFileName"
							elif [ "$stepLog" != "nan" ]; then
								cp "$stepLog" "$stepDest/expectedNA.log"
							fi ;;
						wesfreec)
							[ "$app" != "WGS" ] && copy_or_log "$stepFile" "$stepDest" "$stepFileName" ;;
						wgsfreectrack)
							[ "$var2trackFreec" != "NA" ] && [ "$app" = "WGS" ] && copy_or_log "$stepFile" "$stepDest" "$stepFileName" ;;
						wesfreectrack)
							[ "$var2trackFreec" != "NA" ] && [ "$app" != "WGS" ] && copy_or_log "$stepFile" "$stepDest" "$stepFileName" ;;
						spliceairuncandigene)
							[ "$spliceairuncandigene" = "T" ] && copy_or_log "$stepFile" "$stepDest" "$stepFileName" ;;
						spliceairuncandigenenvarssxls)
							if [ "$spliceairuncandigene" = "T" ]; then
								check_cntvar_copy "${stepFile%.full.xlsx}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 1000000 le
							fi ;;
						spliceairuncandigenenvarsstsv)
							if [ "$spliceairuncandigene" = "T" ]; then
								check_cntvar_copy "${stepFile%.full.tsv.gz}.cntvar" "$stepFile" "$stepDest" "$stepFileName" 0 ge
							fi ;;
						*)
							echo "ERROR : Unknown step condition [$stepCondition]" | tee -a "${copyLog}" ;;
					esac
				done
			done < <(grep -v "^#" "$anaDir/${analysisId}_samples_rawdata.tsv" | cut -f1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepout.conf)
		echo | tee -a ${copyLog}
	done
	
	echo -n  "# INFO - Calculating md5sum ..." | tee -a ${copyLog}
	for i in $(find ${resDir} -type f); do
		md5sum ${i} >> ${resDir}/md5sum.txt
		echo -n "." | tee -a ${copyLog}
	done
	echo | tee -a ${copyLog}
	
	echo "# INFO - Done!" | tee -a ${copyLog}