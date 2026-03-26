#!/bin/bash
pipeVer='20260109'
source /scratch_isilon/groups/dat/apps/MVPGermline/${pipeVer}/conf/path.conf
source ${funcDir}/check.sh
source ${funcDir}/candidateGenes.sh

taskdef="${confDir}/taskdef.conf"
stepdef="${confDir}/stepdef.conf"

# usage
print_usage() {
cat << EOF

#-------------------------------#
# Pipeline usage                #
#-------------------------------#
$ mvp [parameter]

Parameters:
	-t      REQ   STR    Task
	-c      REQ   FILE   Configuration file
	-s      REQ   CSV    Pipeline step(s)
	-b      OPT   CSV    List of sample barcode(s) to process (as they appear into the analysis sample sheet) (purge task only)
	-h      OPT   FLAG   Print usage and exit

Tasks description:
EOF
grep -v "^#" ${taskdef} | while IFS=$'\t' read taskName taskDef taskStep; do
	printf "%-24s %-3s %s %s %s\n" "${taskName}" ":" "${taskDef}" "[${taskStep}]"
done
cat << EOF

Version:
	/scratch_isilon/groups/dat/apps/MVPGermline/${pipeVer}

#-------------------------------#
# Pipeline steps description    #
#-------------------------------#
EOF
grep -v "^#" ${stepdef} | while IFS=$'\t' read stepName stepDef stepSpecie stepApp rest; do
	printf "%-24s %-3s %s %s %s %s %s\n" "${stepName}" ":" "${stepDef}" "-" "${stepSpecie}" "-" "${stepApp}"
done
echo
printf "%-24s %-3s %s\n" "all" ":" "Run all steps, except allshortvar, gutierrezsarprs and tegerpgxgeno"
cat << EOF

#-------------------------------#
# Exemple of configuration file #
#-------------------------------#
EOF
cat ${pipeDir}/exemple.mvp.conf | sed "s/PIPEVER/${pipeVer}/g"
echo
}

# get options
barcode=all
while getopts t:c:s:b:h flag
do
    case "${flag}" in
        t) task="${OPTARG}";;
        c) conf="${OPTARG}";;
        s) ustep="${OPTARG}";;
		b) barcode="${OPTARG}";;
        h) print_usage; exit 1 ;;
        *) print_usage; exit 1 ;;
    esac
done


# cmd line parameters check
echo "# INFO - Checking command line parameters ..."

# task
check_param "${task}" "task parameter [-t] is missing"
knowntaskcsv=$(grep -v "^#" ${taskdef} | while IFS=$'\t' read taskName _; do echo ${taskName}; done | paste -d"," -s -)
IFS=',' read -r -a knowntask <<< "${knowntaskcsv}"
if [[ ! " ${knowntask[*]} " =~ " ${task} " ]]; then
	echo "ERROR : Unrecognized task parameter [${task}]"
	exit 1
fi

# step
if [ "${ustep}" = "all" ]; then
	step=$(grep -v "^#" ${stepdef} | while IFS=$'\t' read stepName stepDef stepSpecie stepApp stepResult stepCond stepAll; do if [ "${stepAll}" = "yes" ]; then echo ${stepName}; fi ; done | paste -d"," -s -)
else
	step="${ustep}"
fi
IFS=',' read -r -a stepuser <<< "${step}"
steptaskcsv=$(grep -v "^#" ${taskdef} | while IFS=$'\t' read taskName taskDef taskStep; do if [ "${taskStep}" != "no step required" ]; then echo ${taskName}; fi ; done | paste -d"," -s -)
IFS=',' read -r -a steptask <<< "${steptaskcsv}"
if [[ " ${steptask[*]} " =~ " ${task} " ]]; then
	check_param "${step}" "step parameter [-s] is missing"
	i=0; while read stepknown; do
		stepknownarr[ $i ]="$stepknown"        
		(( i++ ))
	done < <(grep -v "^#" ${stepdef} | cut -f 1)
	for stepitem in "${stepuser[@]}"; do
		if [[ ! " ${stepknownarr[*]} " =~ " ${stepitem} " ]]; then
			echo "ERROR : Unrecognized step [${stepitem}]"
			exit 1
		fi
	done
fi

# conf
check_param "${conf}" "Config file [-c] is missing"
check_file "conf" "${conf}"
uconf=$(realpath ${conf})
source $uconf

# user configuration check
echo "# INFO - Checking user configuration file [${uconf}] ..."

check_param "${wdir}" "wdir parameter is missing into config file [${uconf}]"
check_directory "wdir" "${wdir}"

check_param "${cnagProd}" "cnagProd parameter is missing into config file [${uconf}]"
if [ "${cnagProd}" != "yes" ] && [ "${cnagProd}" != "no" ]; then
	echo "ERROR : Unrecognized cnagProd parameter [${cnagProd}] into config file [${uconf}]"
	exit 1
fi

#check_param "${consensus}" "consensus parameter is missing into config file [${uconf}]"
#if [ "${consensus}" != "yes" ] && [ "${consensus}" != "no" ]; then
#	echo "ERROR : Unrecognized consensus parameter [${consensus}] into config file [${uconf}]"
#	exit 1
#fi

check_param "${analysisId}" "analysisId parameter is missing into config file [${uconf}]"

if [ "${cnagProd}" = "no" ]; then
	realSampleSheet=$(readlink -e ${sampleSheet})
	check_param "${realSampleSheet}" "sampleSheet parameter is missing into config file [${uconf}]"
	check_file "sampleSheet" "${realSampleSheet}"
fi

check_param "${candidateGenes}" "candidateGenes parameter is missing into config file [${uconf}]"
check_file "candidateGenes" "${geneDir}/${candidateGenes}"

check_param "${pipeConf}" "pipeConf parameter is missing into pipeline configuration file [${uconf}]"
check_file "pipeConf" "${confDir}/${pipeConf}"

source ${confDir}/${pipeConf}

# pipe conf check
echo "# INFO - Checking pipeline configuration file [${confDir}/${pipeConf}] ..."

check_param "${fasta}" "fasta parameter is missing into pipeline configuration file [${confDir}/${pipeConf}]"
check_file "fasta" "${fasta}"
check_file "fasta.fai" "${fasta}.fai"

check_param "${chrList}" "chrList parameter is missing into pipeline configuration file [${confDir}/${pipeConf}]"

stepreq="${confDir}/stepreq.conf"
grep -v "^#" ${stepreq} | while IFS=$'\t' read stepName stepVar varCond checkParam checkFile checkDir; do
	if [[ " ${stepuser[*]} " =~ " ${stepName} " ]]; then
		 varVal="${!stepVar}"
		if [[ ${varCond} != "no" ]]; then
			valCond="${!varCond}"
			check_param "${valCond}" "${varCond} parameter is missing into pipeline configuration file [${confDir}/${pipeConf}]"
			[[ ${valCond} == "NA" ]] && continue
		fi
		[[ ${checkParam} == "yes" ]] && \
			check_param "${varVal}" "${stepVar} parameter is missing into pipeline configuration file [${confDir}/${pipeConf}]"
		[[ ${checkFile} == "yes" ]] && \
			check_file "${stepVar}" "${varVal}"
		[[ ${checkDir} == "yes" ]] && \
			check_directory "${stepVar}" "${varVal}"
			
		if [ "${stepVar}" = "annotToml" ]; then
			for tomlPath in $(grep "^file" ${valCond}); do
				tomlFile=$(echo ${tomlPath} | cut -d "=" -f 2 | sed 's/"//g')
				check_file "tomlFile" "${tomlFile}"
			done
		fi
	fi
done

# get absolute path
realWdir=$(readlink -e ${wdir})
anaDir="${realWdir}/${analysisId}"

# get names for log
launchLog=${realWdir}/${analysisId}.mvp.launch.log
checkLog=${realWdir}/${analysisId}.mvp.check.log
qcLog=${realWdir}/${analysisId}.mvp.qc.log
copyLog=${realWdir}/${analysisId}.mvp.copy.log
copyReportLog=${realWdir}/${analysisId}.mvp.copyReport.log
copyGPAPLog=${realWdir}/${analysisId}.mvp.copyGPAP.log
casesummLog=${realWdir}/${analysisId}.mvp.casesumm.log
purgeLog=${realWdir}/${analysisId}.mvp.purge.log
cleanLog=${realWdir}/${analysisId}.mvp.clean.log
tarLog=${realWdir}/${analysisId}.mvp.tar.log
timeLog=${realWdir}/${analysisId}.mvp.time.log
now=$(date +"%Y/%m/%d - %H:%M:%S")
dateResults=$(date +"%Y%m%d")

# other configuration
source ${confDir}/containers.conf
excludeNode=$(cat /home/groups/dat/jrtrotta/excludeNode.txt)

# get task sub
case "${task}" in
    launch)      source "${pipeDir}/mvp.launch.sh" ;;
    check)       source "${pipeDir}/mvp.check.sh" ;;
    qc)          source "${pipeDir}/mvp.qc.sh" ;;
    copy)        source "${pipeDir}/mvp.copy.sh" ;;
    copyReport)  source "${pipeDir}/mvp.copyReport.sh" ;;
    copyGPAP)    source "${pipeDir}/mvp.copyGPAP.sh" ;;
    casesumm)    source "${pipeDir}/mvp.casesumm.sh" ;;
    purge)       source "${pipeDir}/mvp.purge.sh" ;;
    clean)       source "${pipeDir}/mvp.clean.sh" ;;
    tar)         source "${pipeDir}/mvp.tar.sh" ;;
    time)        source "${pipeDir}/mvp.time.sh" ;;
    email)       source "${pipeDir}/mvp.email.sh" ;;
    *) 
        echo "ERROR: Unknown task [${task}]"
        exit 1
        ;;
esac
