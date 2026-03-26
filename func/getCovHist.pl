#! /usr/bin/env perl
use strict;
use warnings;
use Template qw( );
use experimental 'smartmatch';
use Carp;
use Cwd;
use Getopt::Long;
use List::Util qw(sum);
use File::Basename;
use File::Path;
use POSIX qw(strftime);

my($genomeRef,$genomeData,$targetRef,$targetData,$experiment,$prefix,$readGroup,$output,$help);
	
my $getOpt = GetOptions(
	"x|experiment:s" => \$experiment,
	"gr|genomeRef:s" => \$genomeRef,
	"gd|genomeData:s" => \$genomeData,
	"tr|targetRef:s" => \$targetRef,
	"td|targetData:s" => \$targetData,
	"p|prefix:s" => \$prefix,
	"rg|readGroup:s" => \$readGroup,
	"o|output:s" => \$output,
	"h|help:s" => \$help);
	
my $usage = qq/
Usage:  getCovHist <options>
Options:
	-x, -experiment		REQ	STR	Type of experiment [wgs | target]
	-gr, -genomeRef		REQ	FILE	Genome reference file
	-gd, -genomeData	REQ	FILE	Genome coverage file 
	-tr, -targetRef		REQ	FILE	Target reference file (required only if experiment is <target>)
	-td, -targetData		REQ	FILE	Target coverage file (required only if experiment is <target>)
	-p, -prefix		REQ	STR	Sample, library of interest
	-rg, -readGroup		REQ	STR	Read group type [sample | library]
	-o, -output		REQ	FILE	Output file
	-h, -help		OPT	FLAG	Show this help message and die
	
Description: This command will generate a coverage histogram (able to be read by <getCovMetrics> script)
\n/ ;
	
exit if (!$getOpt);
die ($usage) if (defined $help);
	
# Test parameters
die ("ERROR: <experiment> parameter is required\n") if (!defined $experiment);
die ("ERROR: <genomeRef> parameter is required\n") if (!defined $genomeRef);
die ("ERROR: <genomeData> parameter is required\n") if (!defined $genomeData);
die ("ERROR: <targetRef> parameter is required\n") if ($experiment eq "target" && !defined $targetRef);
die ("ERROR: <targetData> parameter is required\n") if ($experiment eq "target" && !defined $targetData);
die ("ERROR: <prefix> parameter is required\n") if(!defined $prefix);
die ("ERROR: <readGroup> parameter is required\n") if(!defined $readGroup);
die ("ERROR: Unrecognized <experiment> parameter [$experiment]\n") if($experiment ne "target" && $experiment ne "wgs");
die ("ERROR: <genomeRef> file is not readable [$genomeRef]\n") if (!-r $genomeRef);
die ("ERROR: <genomeData> file is not readable [$genomeData]\n") if (!-r $genomeData);
die ("ERROR: <targetRef> file is not readable [$targetRef]\n") if ($experiment eq "target" && !-r $targetRef);
die ("ERROR: <targetData> file is not readable [$targetData]\n") if ($experiment eq "target" && !-r $targetData);
die ("ERROR: Unrecognized <readGroup> parameter [$readGroup]\n") if($readGroup ne "sample" && $readGroup ne "library");


# Prepare hash
my $maxCov = 10000;
#my $maxCov = `cut -f 4 $genomeData | sort -n | tail -n 1`;
my %hashCov;
for (my $cov = 0; $cov <= $maxCov; $cov++) {
	$hashCov{'wgs'}{$cov} = 0;
	$hashCov{'target'}{$cov} = 0 if($experiment eq 'target');
}

# Define stats variables
my ($lengthGenome,$lineGenome,@valGenome,$countGenome,$perGenome,$cumPerGenome);	
my ($lengthTarget,$lineTarget,@valTarget,$countTarget,$perTarget,$cumPerTarget);

# Get lengths
$lengthGenome = `cat $genomeRef | awk 'BEGIN{SUM=0}{ SUM+=\$3-\$2 }END{print SUM}'`;
chomp $lengthGenome;
if ($experiment eq 'target') {
	$lengthTarget = `cat $targetRef | awk 'BEGIN{SUM=0}{ SUM+=\$3-\$2 }END{print SUM}'`;
	chomp $lengthTarget if ($experiment eq 'target');
}

# Populate hash with genome data
open(INCOVGENOME, "$genomeData") || die ("ERROR: Cannot open genomeData file <$genomeData>\n");
while ( $lineGenome = <INCOVGENOME> ) {
	chomp $lineGenome;
	@valGenome = split("\t", $lineGenome);
	
	#$hashCov{'wgs'}{$valGenome[3]} += ($valGenome[2]-$valGenome[1]);
	
	if ($valGenome[3] >= $maxCov) {
		$hashCov{'wgs'}{$maxCov} += ($valGenome[2]-$valGenome[1]); }
	else {
		$hashCov{'wgs'}{$valGenome[3]} += ($valGenome[2]-$valGenome[1]); }
}
close(INCOVGENOME);

# Populate hash with target data
if ($experiment eq 'target') {
	open(INCOVTARGET, "$targetData") || die ("ERROR: Cannot open targetData file <$targetData>\n");
	while ( $lineTarget = <INCOVTARGET> ) {
		chomp $lineTarget;
		@valTarget = split("\t", $lineTarget);
		
		#$hashCov{'target'}{$valTarget[3]} += ($valTarget[2]-$valTarget[1]);
		
		if ($valTarget[3] >= $maxCov) {
			$hashCov{'target'}{$maxCov} += ($valTarget[2]-$valTarget[1]); }
		else {
			$hashCov{'target'}{$valTarget[3]} += ($valTarget[2]-$valTarget[1]); }
	}
	close(INCOVTARGET);
}

# Get output
open (OUTHIST, ">>$output") || die ("ERROR: Cannot open getCovHist output file <$output>\n");
for (my $cov = 0; $cov <= $maxCov; $cov++) {
	$countGenome = $hashCov{'wgs'}{$cov};
	$perGenome = sprintf("%.6f", ($countGenome/$lengthGenome));
	$cumPerGenome += sprintf("%.6f",($perGenome));
	print (OUTHIST "$cov\t$countGenome\t$perGenome\t$cumPerGenome");
	if ($experiment eq 'target') {
		$countTarget = $hashCov{'target'}{$cov};
		$perTarget = sprintf("%.6f",($countTarget/$lengthTarget));
		$cumPerTarget += sprintf("%.6f",($perTarget));
		print (OUTHIST "\t$countTarget\t$perTarget\t$cumPerTarget");
	}
	print (OUTHIST "\n");
}

close(OUTHIST);
