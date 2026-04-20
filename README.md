# MVPGermline
```
#-------------------------------#
# Pipeline usage                #
#-------------------------------#
$ mvp.sh [parameter]

Parameters:
	-t      REQ   STR    Task
	-c      REQ   FILE   Configuration file
	-s      REQ   CSV    Pipeline step(s)
	-b      OPT   CSV    List of sample barcode(s) to process (as they appear into the analysis sample sheet) (purge task only)
	-h      OPT   FLAG   Print usage and exit

Tasks description:
launch                   :   launch pipeline [any step] 
check                    :   check job status, error and outputs [any step] 
qc                       :   check QC metrics [any step] 
copy                     :   copy final outputs into results folder [any step] 
copyReport               :   copy SNVs/INDELs report to be signed (production analysis only) [singshortvar] 
copyGPAP                 :   copy outputs for GPAP submission [roh,exdepth,freec,singmanta,ehshort,ehlong,igvcram] 
casesumm                 :   case summarizer from results folder [singshortvar,roh,mt,cyrius,pypgx,smafind,smncall,ehshort,singmanta] 
purge                    :   purge working folders for re-launching purpose (can be restricted by -b parameter) [any step] 
clean                    :   clean working folders (including intermediate file-saving process) [any step] 
email                    :   generate email draft with step(s) description [any step] 
time                     :   get analysis time [no step required] 
tar                      :   tar analysis folder [no step required] 

Version:
	/scratch_isilon/groups/dat/apps/MVPGermline/20260109

#-------------------------------#
# Pipeline steps description    #
#-------------------------------#
singshortvar             :   SNVs/INDELs by sample - All species - [WGS|WES]
mt                       :   GATK Mitochondrial pipeline by sample - Human only - [WGS|WES]
roh                      :   Runs of Homozygosity by sample - All species - [WGS|WES]
multshortvar             :   SNVs/INDELs by pedigree - All species - [WGS|WES]
allshortvar              :   SNVs/INDELs without annotation for whole analysis - All species - [WGS|WES]
singmanta                :   SVs by sample with Manta - All species - [WGS|WES]
multmanta                :   SVs by pedigree with Manta - All species - [WGS|WES]
clinsv                   :   CNVs by sample with ClinSV - All species - [WGS]
exdepth                  :   CNVs by sample with ExomeDetph - All species - [WES]
freec                    :   CNVs by sample with Control-FREEC - All species - [WGS|WES]
stripy                   :   STRs by sample with Stripy - Human only - [WGS|WES]
ehshort                  :   STRs by sample with Expansion Hunter on short catalog of variants - Human only - [WGS|WES]
ehlong                   :   STRs by sample with Expansion Hunter on long catalog of variants - Human only - [WGS|WES]
smafind                  :   SMA finder by sample - Human only - [WGS|WES]
smncall                  :   SMN caller by sample - Human only - [WGS|WES]
cyrius                   :   CYP2D6 by sample - Human only - [WGS|WES]
pypgx                    :   PyPGx by sample - Human only - [WGS|WES]
gauchian                 :   GBA by sample - Human only - [WGS|WES]
hlahd                    :   MHC by sample with HLA-HD - Human only - [WGS]
hlakir                   :   HLA and KIR by sample with T1K - Human only - [WGS]
somalier                 :   Somalier relate and ancestry by analysis and pedigree - All species - [WGS|WES]
mosdepth                 :   Coverage by sample - All species - [WGS|WES]
igvcram                  :   CRAM by sample for IGV visualization - All species - [WGS|WES]
bamtocram                :   BAM to CRAM convertion by sample - All species - [WGS|WES]
gutierrezsarprs          :   PRS by sample specific to GUTIERREZSAR project - Human only - [WGS|WES]
tegerpgxgeno             :   PGx genotype by sample specific to TEGER project - Human only - [WGS|WES]

all                      :   Run all steps, except allshortvar, gutierrezsarprs and tegerpgxgeno

#-------------------------------#
# Exemple of configuration file #
#-------------------------------#
# Folder where the analysis structure will be created
wdir=/scratch_isilon/groups/dat/apps/MVPGermline/20260109/TEST
# Experiment is from CNAG production [yes|no]
cnagProd=no
# BAM from Georgia instead of standard production BAMs
georgia=no
# Analysis ID (Subproject name as appears in LIMS if cnagProd=yes)
analysisId=TEST_GRCh38
# Sample sheet in case cnagProd=no
# Format tsv: #pedigree barcode sampleName sex[1(male)|2(female)] sampleStatus[1(unaffected)|2(affected)|-9(NA)] subproject app[WGS|CaptureKitName] motherId[barcode|-9(NA)] fatherId[barcode|-9(NA)] BAMorCRAM GVCForNA VCForNA)
# Header: #pedigree	barcode	sampleName	sex	sampleStatus	subproject	app	motherId	fatherId	bamcram	gvcf	vcf
# bamcram format: absolute path to BAM or CRAM
# gvcf format: absolute path to gVCF by chr (file name: *.CHRNAME.*.g.vcf.gz) or NA if not available
# vcf format: absolute path to VCF by chr (file name: *.CHRNAME.*.vcf.gz) or NA if not available
sampleSheet=/scratch_isilon/groups/dat/apps/MVPGermline/20260109/TEST/TEST_GRCh38.sampleSheet.tsv
# Pipeline configuration file (found at /scratch_isilon/groups/dat/apps/MVPGermline/20260109/conf)
pipeConf=hsapiens.GRCh38.conf
# Candidate genes configuration (found at /scratch_isilon/groups/dat/apps/MVPGermline/Candidate_Genes)
candidateGenes=ACMG.snpEff_v5_2.genes.GRCh38.mane.1.2.refseq.conf
```
