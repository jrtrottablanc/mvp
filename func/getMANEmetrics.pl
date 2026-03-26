#! /usr/bin/env perl
use strict;
use warnings;
use Carp;
use Cwd;
use Getopt::Long;
use Data::Dumper;

my($input,$covn,$output,$help);

my $getOpt = GetOptions(
    "i|input:s"  => \$input,
    "cn|covn:s"  => \$covn,
    "o|output:s" => \$output,
    "h|help:s"   => \$help
);

my $usage = qq/
Usage:  getCovHist <options>
Options:
    -i, -input     REQ FILE Input file
    -cn, -covn     REQ CSV  Cn values
    -o, -output    REQ FILE Output file
    -h, -help      OPT FLAG Show this help message and die
\n/;

exit if (!$getOpt);
die ($usage) if (defined $help);

my @valCn = split(",", $covn);

# READ INPUT
my %data;
open(INDATA, "$input") || die ("ERROR: Cannot open input file <$input>\n");
while (my $lineData = <INDATA>) {
    chomp $lineData;
    my @valData = split("\t", $lineData);
    
    my $chr    = $valData[0];
    my $start  = $valData[1];
    my $end    = $valData[2];
    my $length = $end - $start;
    my $info   = $valData[3];
    my @valInfo = split(";", $info);
    my $type   = $valInfo[0];
    my $symbol = $valInfo[1];
    my $ensg   = $valInfo[2];
    my $enst   = $valInfo[3];
    my $ense   = $valInfo[4];
    my $itemID = $valInfo[5];
    my $refseq = $valInfo[6];
    my $strand = $valInfo[7];
    my $mean   = $valData[4];

    # Uniq key
    my $key = "$symbol\_$enst";

    # Metadata
    $data{$key}{$type}{'symbol'} = $symbol;
    $data{$key}{$type}{'ensg'}   = $ensg;
    $data{$key}{$type}{'enst'}   = $enst;
    $data{$key}{$type}{'refseq'} = $refseq;
    $data{$key}{$type}{'strand'} = $strand;
    $data{$key}{$type}{'chr'}    = $chr;

    # Data per item
    $data{$key}{$type}{'item'}{$itemID}{'ense'}   = $ense;
    $data{$key}{$type}{'item'}{$itemID}{'chr'}    = $chr;
    $data{$key}{$type}{'item'}{$itemID}{'start'}  = $start;
    $data{$key}{$type}{'item'}{$itemID}{'end'}    = $end;
    $data{$key}{$type}{'item'}{$itemID}{'length'} = $length;

    # Total length of item
    $data{$key}{$type}{'totalLength'} += $length;

    # Weighted mean
    $data{$key}{$type}{'item'}{$itemID}{'mean'} = $mean;
    $data{$key}{$type}{'sumMean'} += $mean*$length;
    $data{$key}{$type}{'avgMean'} = sprintf("%.2f", $data{$key}{$type}{'sumMean'}/$data{$key}{$type}{'totalLength'});

    # Weighted Cn
    my $n = 5;
    foreach (@valCn) {
        my $cPer = sprintf("%.2f", $valData[$n]/$length*100);
        $data{$key}{$type}{'item'}{$itemID}{"C$_"} = $cPer;
        if ($cPer < 100) {
            $data{$key}{$type}{'item'}{$itemID}{"badC$_"} = $itemID;
        } else {
            $data{$key}{$type}{'item'}{$itemID}{"badC$_"} = ".";
        }
        $n++;
        $data{$key}{$type}{"sumC$_"} += $cPer*$length;
        $data{$key}{$type}{"avgC$_"} = sprintf("%.2f", $data{$key}{$type}{"sumC$_"}/$data{$key}{$type}{'totalLength'});
    }
}
close(INDATA);

# WRITE OUTPUT
open (OUTDATA, ">>$output") || die ("ERROR: Cannot open output file <$output>\n");

# Header
print OUTDATA "#geneSymbol";
print OUTDATA "\tintervalType";
print OUTDATA "\tavgMean";
foreach (@valCn) {
    print OUTDATA "\tavgC".$_;
}
print OUTDATA "\tcsvIntervalID";
print OUTDATA "\tcsvMean";
foreach (@valCn) {
    print OUTDATA "\tcsvC".$_;
    print OUTDATA "\tcsvBadC".$_;
}
print OUTDATA "\tENSG";
print OUTDATA "\tENST";
print OUTDATA "\tREFSEQ";
print OUTDATA "\tcsvEnse";
print OUTDATA "\tstrand";
print OUTDATA "\tchr";
print OUTDATA "\tcsvLength";
print OUTDATA "\tcsvStart";
print OUTDATA "\tcsvEnd\n";

# Data
foreach my $key (sort keys %data) {
    foreach my $type (sort keys %{$data{$key}}) {

        # CSV data
        my @itemCSV   = ();
        my @enseCSV   = ();
        my @lengthCSV = ();
        my @startCSV  = ();
        my @endCSV    = ();
        my @meanCSV   = ();
        my @cnCSV     = ();
        my @badcnCSV  = ();

        foreach my $itemID (sort { $a <=> $b } keys %{$data{$key}{$type}{'item'}}) {
            push @itemCSV,   $itemID;
            push @enseCSV,   $data{$key}{$type}{'item'}{$itemID}{'ense'};
            push @lengthCSV, $data{$key}{$type}{'item'}{$itemID}{'length'};
            push @startCSV,  $data{$key}{$type}{'item'}{$itemID}{'start'};
            push @endCSV,    $data{$key}{$type}{'item'}{$itemID}{'end'};
            push @meanCSV,   $data{$key}{$type}{'item'}{$itemID}{'mean'};
            foreach (@valCn) {
                push @{$cnCSV[$_]},    $data{$key}{$type}{'item'}{$itemID}{"C$_"};
                push @{$badcnCSV[$_]}, $data{$key}{$type}{'item'}{$itemID}{"badC$_"};
            }
        }

        # Write output
        print OUTDATA $data{$key}{$type}{'symbol'};
        print OUTDATA "\t$type";
        print OUTDATA "\t".$data{$key}{$type}{'avgMean'};
        foreach (@valCn) {
            print OUTDATA "\t".$data{$key}{$type}{"avgC$_"};
        }
        print OUTDATA "\t".join(',' , @itemCSV);
        print OUTDATA "\t".join(',' , @meanCSV);
        foreach (@valCn) {
            print OUTDATA "\t".join(',' , @{$cnCSV[$_]} );
            print OUTDATA "\t".join(',' , @{$badcnCSV[$_]} );
        }
        print OUTDATA "\t$data{$key}{$type}{'ensg'}";
        print OUTDATA "\t$data{$key}{$type}{'enst'}";
        print OUTDATA "\t$data{$key}{$type}{'refseq'}";
        print OUTDATA "\t".join(',' , @enseCSV);
        print OUTDATA "\t$data{$key}{$type}{'strand'}";
        print OUTDATA "\t$data{$key}{$type}{'chr'}";
        print OUTDATA "\t".join(',' , @lengthCSV);
        print OUTDATA "\t".join(',' , @startCSV);
        print OUTDATA "\t".join(',' , @endCSV);
        print OUTDATA "\n";
    }
}
close(OUTDATA);
