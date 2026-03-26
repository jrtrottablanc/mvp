#!/bin/bash

# Option treatment
while getopts :s:p: opt
do
	case "$opt" in
		s )	SAMP="$OPTARG";;
		p )	SUBPROJ="$OPTARG";;
	esac
done
shift `expr "$OPTIND" - 1`

# Script treatment
if [ -z ${SAMP} ]; then
	echo "Sample barcode is missing"
elif [ -z ${SUBPROJ} ]; then
	echo "Subproject barcode is missing"
else
	# lims_url = "http://172.16.10.26/lims/lims_q_2/?"
	# lims_url = "https://lims.cnag.cat/lims/lims_q_2/?"	

	echo -e "#Subproject\tSample_barcode\tCollaborator_Sex\tPCR_Sex\tCoverage_Sex"
	mysql -h lims.internal.cnag.eu -u lims_ro -p4eCrrEG8 -D lims -B --column-names=0 -e \
	"SELECT sequencing_subproject.subproject_name as subprojName,
	sequencing_sample.barcode as sampBarcode,
	sequencing_sample.sex as sampSex,
	sequencing_cnaggenderpcr.name as pcrSex,
	sequencing_samplesubprojectstats.y_auto_ratio as ratioSex
	FROM sequencing_sample
	LEFT JOIN sequencing_qcforsamples ON sequencing_qcforsamples.sample_id = sequencing_sample.id
	LEFT JOIN sequencing_cnaggenderpcr ON sequencing_cnaggenderpcr.id = sequencing_qcforsamples.cnag_gender_pcr_id
	LEFT JOIN sequencing_samplesubproject ON sequencing_samplesubproject.sample_id = sequencing_sample.id
	LEFT JOIN sequencing_samplesubprojectstats ON sequencing_samplesubproject.id = sequencing_samplesubprojectstats.samplesubproject_id
	LEFT JOIN sequencing_subproject ON sequencing_subproject.id = sequencing_samplesubproject.subproject_id
	WHERE sequencing_sample.barcode = '${SAMP}'
	AND sequencing_subproject.subproject_name = '${SUBPROJ}'
	AND sequencing_samplesubprojectstats.qc_stats = 1"
fi
