#!/bin/bash

VMEM=12
# parameters definition
DATADIR=
FIND=
JOIN=
ANNO=
PARSE=
SPLIT=
MINIMODE=
BUBLEMODE=
while getopts ":i:dfjapsFMBh" OPTION
do
	case $OPTION in
		i) TSVFILE=$OPTARG;;
		d) DATADIR=$OPTARG;;
		f) FIND=1;;
		j) JOIN=1;;
		a) ANNO=1;;
		p) PARSE=1;;
		s) SPLIT=1;;
		F) FIND=1; JOIN=1; ANNO=1; PARSE=1; SPLIT=1;;
		M) MINIMODE=1;;
		B) MINIMODE=1; BUBLEMODE=1;;
		h) usage; exit 1;;
		?) usage; exit 1;;
	esac
done

if [[ -z "$TSVFILE" ]]; then
    echo "ERROR: No TSV file provided (-i)" >&2
    exit 1
fi

if [[ ! -f "$TSVFILE" ]]; then
    echo "ERROR: File not found: $TSVFILE" >&2
    exit 1
fi

tsvFile="$TSVFILE"
echo $tsvFile
cat $tsvFile | perl -ne '
@cols = split "\t", $_, -1;
$cols[4] =~ s/^-//;
if ($index2parse) {
 if ($cols[$indexLength]) {
  $cols[$indexLength] =~ s/^-//;
  $cols[$index2parse] =~ s/;SVLEN=\d+//;
 } else {
  $cols[$index2parse] =~ s/;SVLEN=(\d+)// and $cols[$indexLength] = $1;
 }
 $cols[$index2parse] =~ s/SVTYPE=//;
 $cols[$index2parse] =~ s/;END=\d+//;
 $cols[$index2parse] =~ s/;SAMPLES=/\t/;
 $cols[$index2parse] =~ s/;COUNT=(\d+)(,(\d+))?(,(\S+))?.*/\t$1\t$3\t$5/;
} else {
 for ($i = 0; $i <= $#cols; $i++) {
#  if ($cols[$i] eq "Illumina.similar.counts") {
#   $index2add = $i;
#  } elsif ($cols[$i] !~ /(Field4|Field5|Field6|Field7|Field8|Field9|Field11)$/) {
   if ($cols[$i] !~ /(Field4|Field5|Field6|Field7|Field8|Field9|Field11)$/) {
	push @indices, $i;
     if ($cols[$i] eq "SV_length") {
         $indexLength = $i;
     } elsif ($cols[$i] eq "SV_type") {
         $indexType = $i;
     } elsif ($cols[$i] eq "REF") {
         $cols[$i] = "REF";
     } elsif ($cols[$i] eq "ALT") {
         $cols[$i] = "ALT";
     } elsif ($cols[$i] eq "SimInfo") {
         $index2parse = $i;
         $cols[$i] = "SV_type_original";
    $cols[$i] .= "\tIllumina.samples";
    $cols[$i] .= "\tIllumina.exact.counts";
    $cols[$i] .= "\tIllumina.similar.counts";
    $cols[$i] .= "\tIllumina.other.counts";
   }
  }
 }
}
print join "\t", @cols[@indices]' > ${tsvFile}.intFreq


