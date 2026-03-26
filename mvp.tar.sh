touch ${cleanLog}
	
	echo "# INFO - Submiting TAR MVPGermline pipeline analysis [${now}] ..." | tee -a ${tarLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${tarLog}
	
	jobLab="${analysisId}.mvp.tar"
	jobCmd="${realWdir}/${jobLab}.cmd"
	jobLog="${realWdir}/${jobLab}.jobID.log"
	echo "# INFO - Submitting mvp tar ..." | tee -a ${tarLog}
	apptainer run --no-home --bind ${bindDir} ${contDir}/${perlCont} tpage \
	--define qos=marathon \
	--define cpu=1 \
	--define mem=8000 \
	--define time="71:55:00" \
	--define excludeNode=${excludeNode} \
	--define chdir=${realWdir} \
	--define pipeDir=${pipeDir} \
	--define jobLab=${jobLab} \
	--define analysisId=${analysisId} \
	--define tarLog=${tarLog} \
	${ttDir}/tar.tt > ${jobCmd}
	JID=$(sbatch --parsable ${jobCmd})
	echo -e "${jobCmd}\t${JID}" | tee -a ${tarLog}
	
	echo "# INFO - Done!" | tee -a ${tarLog}
