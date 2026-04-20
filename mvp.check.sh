touch ${checkLog}
	
	echo "# INFO - Checking MVPGermline pipeline results [${now}] ..." | tee -a ${checkLog}
	
	echo "# INFO - Step(s) required : [${step}]" | tee -a ${checkLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${checkLog}
	
	echo "# INFO - Checking MVPGermline pipeline jobs status ..." | tee -a ${checkLog}
	for i in $(cut -f 2 ${anaDir}/*.mvp.jobID.log); do sacct -bn -j ${i} | awk '{print $2}'; done | sort | uniq -c | awk '{printf "%-15s %s\n", $2, $1}' | tee -a ${checkLog}
	
	# loop on userstep
	IFS=',' read -r -a stepuser <<< "${step}"
	for stepitem in "${stepuser[@]}"; do
	
		# jobs status
		echo "# INFO - Checking jobs status for step [${stepitem}] ..." | tee -a ${checkLog}
		while read stepName stepDir; do
			for jobLog in $(find ${anaDir}/${stepDir} -name '*jobID.log'); do 
				for i in $(cut -f 2 $jobLog); do sacct -bn -j ${i} | awk '{print $2}'; done
			done
		done < <(grep "^${stepitem}\s" ${confDir}/stepcheck.conf) | sort | uniq -c | awk '{printf "%-15s %s\n", $2, $1}' | tee -a ${checkLog}
	
		# error logs
		echo "# INFO - Checking ERROR logs for step [${stepitem}] ..." | tee -a ${checkLog}
		while read stepName stepDir; do
			for errLog in $(find ${anaDir}/${stepDir} -name 'ERROR.log'); do 
				if [ -s $errLog ]; then echo "ERROR : Found error at [${errLog}]" | tee -a ${checkLog}; fi
			done
		done < <(grep "^${stepitem}\s" ${confDir}/stepcheck.conf)
	
		# outputs
		echo "# INFO - Checking OUTPUTs for step [${stepitem}] ..." | tee -a ${checkLog}
		while read stepName stepSub stepCondition stepOrga stepOutput stepResults stepLogs; do
			
			# organism
			if [ "${stepOrga}" != "all" ] && [ "${stepOrga}" != "${organism}" ]; then continue; fi
			
			nSampAna=$(grep -v "^#" ${anaDir}/${analysisId}_samples_rawdata.tsv | wc -l)	
			
			while read -r pedigree; do
				pedDir="${anaDir}/${pedigree}"
				nSampPed=$(grep -vc "^#" "$pedDir/${pedigree}_samples_rawdata.tsv")

				grep "^${pedigree}\s" "$anaDir/${analysisId}_samples_rawdata.tsv" |
				while read -r ped sample app sex bcam gvcf vcf; do

					stepFile=$(printf "%s" "$stepOutput" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANAID|$analysisId|g" \
							  -e "s|ANA/|${anaDir}/|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|SUB|$stepSub|g" \
							  -e "s|APP|$app|g" \
							  -e "s|MANEPREFIX|$manePrefix|g")
					
					stepLog=$(printf "%s" "$stepLogs" \
						| sed -e "s|STEP|$stepName|g" \
							  -e "s|ANAID|$analysisId|g" \
							  -e "s|ANA/|${anaDir}/|g" \
							  -e "s|PED|$ped|g" \
							  -e "s|SAMP|$sample|g" \
							  -e "s|SUB|$stepSub|g" \
							  -e "s|APP|$app|g")

					case "$stepCondition" in
						no)
							check_missing "$stepFile" ;;
						nsana)
							[ "$nSampAna" -gt 1 ] && check_missing "$stepFile" ;;
						nsped)
							[ "$nSampPed" -gt 1 ] && check_missing "$stepFile" ;;
						prod)
							limsSubproj=$($funcDir/limsq_nhopt -nH -sp "$analysisId" -lanepf fail,waiting,under_review | cut -d ";" -f2 | sort -u)
							[ -n "$limsSubproj" ] && check_missing $stepFile ;;
						nvarssxls)
							check_cntvar "${stepFile%.full.xlsx}.cntvar" "$stepFile" 1000000 le ;;
						nvarsstsv)
							check_cntvar "${stepFile%.full.tsv.gz}.cntvar" "$stepFile" 0 ge ;;
						nvarmthtml)
							check_cntvar "${stepFile%.html}.vcf.gz.cntvar" "$stepFile" 0 gt ;;
						nvarsmvcf)
							[ "$var2trackManta" != "NA" ] && check_cntvar "${stepFile%.full.vcf.gz}.cntvar" "$stepFile" 0 gt ;;
						nvarsmtbi)
							[ "$var2trackManta" != "NA" ] && check_cntvar "${stepFile%.full.vcf.gz.tbi}.cntvar" "$stepFile" 0 gt ;;
						wgs)
							[ "$app" = "WGS" ] && check_missing "$stepFile" ;;
						wes)
							[ "$app" != "WGS" ] && check_missing "$stepFile" ;;
						wesfreec)
							[ "$app" != "WGS" ] && [ ! -f ${stepLog} ] && check_missing "$stepFile" ;;
						wgsfreectrack)
							[ "$var2trackFreec" != "NA" ] && [ "$app" = "WGS" ] && [ ! -f ${stepLog} ] && check_missing "$stepFile" ;;
						wesfreectrack)
							[ "$var2trackFreec" != "NA" ] && [ "$app" != "WGS" ]  && [ ! -f ${stepLog} ]&& check_missing "$stepFile" ;;
						spliceairuncandigene)
							[ "$spliceairuncandigene" = "T" ] && check_missing "$stepFile" ;;
						spliceairuncandigenenvarssxls)
							if [ "$spliceairuncandigene" = "T" ]; then
								check_cntvar "${stepFile%.full.xlsx}.cntvar" "$stepFile" 1000000 le
							fi ;;
						spliceairuncandigenenvarsstsv)
							if [ "$spliceairuncandigene" = "T" ]; then
								check_cntvar "${stepFile%.full.tsv.gz}.cntvar" "$stepFile" 0 ge
							fi ;;
						*)
							echo "ERROR : Unknown step condition [$stepCondition]" | tee -a "${checkLog}" ;;
					esac
				done
			done < <(grep -v "^#" "$anaDir/${analysisId}_samples_rawdata.tsv" | cut -f1 | sort -u)
		done < <(grep "^${stepitem}\s" ${confDir}/stepout.conf)
	done
	
	echo "# INFO - Done!" | tee -a ${checkLog}
