echo "# INFO - Analysis folder : [${anaDir}]"
	
	echo "# INFO - Step(s) required : [${step}]"
	IFS=',' read -r -a stepuser <<< "${step}"
	
	mysqlOpt=" -h lims.internal.cnag.eu -u lims_ro -p4eCrrEG8 -D lims -B --column-names=0 -e "
	app=$(grep -v "^#" ${anaDir}/${analysisId}_samples_info.tsv | cut -f 7 | sort -u)
	mvpdoc="CNAG_MVP_pipeline_GRCh38_v5_WGS.pdf"
	if [ "$app" != "WGS" ]; then mvpdoc="NA"; fi

cat << EOF
#################################
EMAIL SUBJECT:

CNAG - ${analysisId} Variant Analysis Results

#################################
EMAIL ADDRESS
TO :
EOF
mysql ${mysqlOpt} "SELECT c.email
FROM sequencing_subproject s
JOIN sequencing_subprojectcontactslist scl ON s.id = scl.subproject_id
JOIN sequencing_contact c ON c.id = scl.contact_id
WHERE s.subproject_name = '${analysisId}'
AND scl.pi = 1";
cat << EOF	
CC:
EOF
mysql ${mysqlOpt} "SELECT c.email
FROM sequencing_subproject s
JOIN sequencing_subprojectcontactslist scl ON s.id = scl.subproject_id
JOIN sequencing_contact c ON c.id = scl.contact_id
WHERE s.subproject_name = '${analysisId}'
AND scl.data_transfer = 1";
cat << EOF
sergi.beltran@cnag.eu
raul.tonda@cnag.eu
projectmanager@cnag.eu

#################################
EMAIL CONTENT:

Dear Dr. XXX,

We have uploaded into our FTP the results of our variants analysis pipeline for your experiment ${analysisId}.
folder: ${analysisId}/YYYYMMDD

You can access with free Windows GUI software such as WinSCP, or via the Unix command line using sftp.
The data will remain available for two weeks; please let us know if you have not been able to download it within that period.

The results include:
EOF
for stepitem in "${stepuser[@]}"; do
	stepdesc=$(grep "^${stepitem}" ${stepdef} | cut -f 2)
	steploc=$(grep "^${stepitem}" ${stepdef} | cut -f 5)
	stepfilt=$(grep "^${stepitem}" ${stepdef} | cut -f 6)
	if [ "${stepfilt}" = "no" ]; then
		echo -e "- ${stepdesc} (folder: ${steploc})"; fi
	if [ "${stepfilt}" = "wgs" ] && [ "$app" = "WGS" ]; then
		echo -e "- ${stepdesc} (folder: ${steploc})"; fi
	if [ "${stepfilt}" = "wes" ] && [ "$app" != "WGS" ]; then
		echo -e "- ${stepdesc} (folder: ${steploc})"; fi
done
echo

if [ "${mvpdoc}" != "NA" ]; then
	echo -e "The file \"${mvpdoc}\" provides a detailed description of the results, along with guidance for variant filtering and interpretation."
fi

cat << EOF
Additionally, "${pipeConf%.conf}.settings.json" contains the corresponding annotation details and program version specifications.
EOF

if [ -f ${copyGPAPLog} ]; then
	echo -e "\nYour samples have also been uploaded into the GPAP."
fi

cat << EOF

Please, don't hesitate to contact us if you need any help or clarification.
Best regards,

YOUR SIGNATURE

#################################
EOF