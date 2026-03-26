touch ${copyReportLog}
	
	echo "# INFO - Copying MVPGermline pipeline production report [${now}] ..." | tee -a ${copyReportLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${copyReportLog}
	
	IFS=',' read -r -a stepuser <<< "${step}"
	
	if [ "${step}" != "singshortvar" ]; then
		echo "ERROR : copyReport only available for step [singshortvar]" | tee -a ${copyReportLog}
		exit 1
	fi
	reportDir="/scratch_isilon/groups/dat/projects/reports"		
	while read pedigree sample sampleName sex sampleStatus subproject app motherId fatherId BCAM GVCF VCF; do
		if [ -f ${anaDir}/${analysisId}_Results/*/${pedigree}/${sample}/SNV-InDels/${sampleName}_${sample}_${analysisId}_*_FOR-017_report.pdf ]; then
			if [ ! -f ${reportDir}/${analysisId}/${sampleName}_${sample}_${analysisId}_*_FOR-017_report-signed.pdf ]; then
				echo "# INFO - Copying report to be signed into report folder [${reportDir}/${analysisId}]" | tee -a ${copyReportLog}
				mkdir -p ${reportDir}/${analysisId}
				chmod g+w ${reportDir}/${analysisId}
				cp ${anaDir}/${analysisId}_Results/*/${pedigree}/${sample}/SNV-InDels/${sampleName}_${sample}_${analysisId}_*_FOR-017_report.pdf \
				${reportDir}/${analysisId}/
			else
				echo "# INFO - Copying back signed report into SNV-InDels folder [${anaDir}/${analysisId}_Results/*/${pedigree}/${sample}/SNV-InDels/]" | tee -a ${copyReportLog}
				rm ${anaDir}/${analysisId}_Results/*/${pedigree}/${sample}/SNV-InDels/${sampleName}_${sample}_${analysisId}_*_FOR-017_report.pdf
				cp ${reportDir}/${analysisId}/${sampleName}_${sample}_${analysisId}_*_FOR-017_report-signed.pdf \
				${anaDir}/${analysisId}_Results/*/${pedigree}/${sample}/SNV-InDels/
			fi
		else
			echo "# INFO - Report is not available for sample [${sample}]" | tee -a ${copyReportLog}
		fi
	done < <(grep -v "^#" ${anaDir}/${analysisId}_samples_info.tsv)
	
	echo "# INFO - Done!" | tee -a ${copyReportLog}
