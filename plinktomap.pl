#!/usr/bin/perl
# $Revision: 0.18 $
# $Date: 2020/07/22 $
# $Id: plinktomap.pl $
# $Author: Michael Bekaert $
#
# RAD-tags to Genetic Map (radmap)
# Copyright (C) 2016-2020 Bekaert M <michael.bekaert@stir.ac.uk>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# POD documentation - main docs before the code

=head1 NAME

RAD-tags to Genetic Map (radmap)

=head1 SYNOPSIS

  # Command line help
  ..:: RAD-tags to Genetic Map ::..

  Usage: ./genetic_mapper.pl [options]

  # LepMap pre-processing
    --lepmap      MANDATORY
    or
    --lepmap3     MANDATORY
    --ped         MANDATORY
    --meta        MANDATORY

    STDOUT > LepMap (linkage) input file

  # Pre-processing
    --snpassoc    MANDATORY
    or
    --arff        MANDATORY
    or
    --ade         MANDATORY
    --plink       MANDATORY
    --ped         MANDATORY
    --meta        MANDATORY
    --map         OPTIONAL
    --gmap        OPTIONAL
    --female      OPTIONAL

    STDOUT > SNPassoc input file
    STDERR 2> Genetic Map

  # Post GWAS processing
    --genetic     MANDATORY
    --extra       MANDATORY (at least once)
    --markers     OPTIONAL
    --fasta       OPTIONAL
    --pos         OPTIONAL
    --lod         OPTIONAL

    STDOUT > Genetic Map

  # Export marker and genotype for publication (Table S)
    --plink       MANDATORY
    --ped         MANDATORY
    --markers     OPTIONAL
    --fasta       OPTIONAL
    --pos         OPTIONAL
    --table       MANDATORY

  # Manual editing
    --ped         MANDATORY
    --genetic     MANDATORY
    --edit        MANDATORY

    STDOUT > Mappable markers list

  Options
    --meta <pedigree file>
         The pedigree file consists of on columns 1-4+. The columns are separated by
         tabs. The columns 1-4 are individual name, father, mother and sex; the next
         columns are for extra phenotypes: phenotype_1 to phenotype_n. The phenotypes
         are not required, but will be helpful for the GWAS analysis.
           sample     father  mother  sex  phenotype_1
           F1_C2_070  P0_sir  P0_dam  M    30
           F1_C2_120  P0_sir  P0_dam  F    1
           P0_dam     0       0       F    -
           P0_sir     0       0       M    -
    --plink <plink map file>
         PLINK MAP file path with full haplotypes.
    --ped <plink ped file>
         PLINK PED file path with full haplotypes.
    --map <mappable markers list>
         Mappable markers list as generated by LepMap "SeparateChromosomes" and
         "JoinSingles" functions.
    --gmap <ordered markers file>
         Ordered genetic map generated by LepMap.
    --genetic <genetic map file>
         Genetic Map as generated by R/SNPAssoc pre-processing step.
    --markers <batch_<n>.catalog.tags.tsv file>
         Path to STACKS catalog.tag file, including marker sequences and positions.
         (incompatible with --fasta)
    --fasta <uniq.full.fasta file>
         Path to dDocent uniq.full.fasta file, including marker sequences. (incompatible
         with --markers)
    --extra
         GWAS results generated by R/SNPassoc (csv format) to be added to the genetic map.
    --lod
         Convert the P-value of the GWAS results to LOD (LOD=-log(P-value)/log(10)).
    --pos
         Provide the marker chromosome/contig and location. (requires --markers)
    --female
         Select the female only map rather than male or average mapping. (requires --gmap)
    --snpassoc
         Enable R/SNPAssoc pre-processing.
    --arff
         Enable Weka ARFF format.
    --ade
         Enable R/ade pre-processing.
    --lepmap
         Enable LepMap pre-processing.
    --table
         Enable export for publication for markers and genotypes.
    --edit
         Enable Manual editing mode.
    --select
         Provide the list of id to select


=head1 DESCRIPTION

Perl script for the analyse RAD-tags and generate the Genetic Map with GWAS. The script
handles the multiple file conversions. PLINK _classic_ file L<PED|http://pngu.mgh.harvard.edu/~purcell/plink/data.shtml#ped>
and L<MAP|http://pngu.mgh.harvard.edu/~purcell/plink/data.shtml#map> are required as well as a pedigree file.


=head1 FEEDBACK

User feedback is an integral part of the evolution of this modules. Send your comments
and suggestions preferably to author.

=head1 AUTHOR

B<Michael Bekaert> (michael.bekaert@stir.ac.uk)

The latest version of genetic_mapper.pl is available at

  https://github.com/pseudogene/radmap

=head1 LICENSE

Copyright 2016-2020 - Michael Bekaert

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings;
use Getopt::Long;

#----------------------------------------------------------
our ($VERSION) = 0.18;

#----------------------------------------------------------
my ($threads, $female, $tableS, $arff, $remap, $lepmap, $lepmap3, $ade, $snpassoc, $edit, $loc, $lod, $plink, $ped, $parentage, $map, $genmap, $genetic, $markers, $fasta, $selectlist) = (10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
my @extra;
GetOptions(
           'plink:s'   => \$plink,
           'ped:s'     => \$ped,
           'meta:s'    => \$parentage,
           'map:s'     => \$map,
           'gmap:s'    => \$genmap,
           'genetic:s' => \$genetic,
           'extra:s'   => \@extra,
           'female!'   => \$female,
           'lepmap!'   => \$lepmap,
           'lepmap3!'  => \$lepmap3,
           'pos!'      => \$loc,
           'lod!'      => \$lod,
           'edit!'     => \$edit,
           'ade!'      => \$ade,
           'snpassoc!' => \$snpassoc,
           'table!'    => \$tableS,
           'markers:s' => \$markers,
           'fasta:s'   => \$fasta,
           'select:s'  => \$selectlist,
           'arff!'     => \$arff,
           'remap!'    => \$remap
          );
my %parents_table;
my $count_meta = 0;
if (defined $parentage && -r $parentage && open(my $in, q{<}, $parentage))
{
    #
    #sample	father	mother	Sex	[..]
    #
    while (<$in>)
    {
        next if (m/^#/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 4 && defined $data[0] && defined $data[1] && defined $data[2] && defined $data[3])
        {
            $count_meta = scalar @data - 4 if ($count_meta < scalar @data - 4);
            @{$parents_table{$data[0]}} = @data;
        }
    }
    close $in;
}

my %selected;
if (defined $selectlist && -r $selectlist && open(my $in, q{<}, $selectlist))
{
    while (<$in>)
    {
        next if (m/^#/);
        chomp;
        my @tmp = split m/\t/x;
        $selected{$tmp[0]} = $tmp[0] if (exists $tmp[0]);
    }
    close $in;
}

#To LepMap
if (scalar keys %parents_table > 0 && ($lepmap || $lepmap3) && defined $ped && -r $ped && open(my $in, q{<}, $ped))
{
    my %table = (A => 1, C => 2, G => 3, T => 4, N => 0, 0 => 0);
    my $last = 0;

    # PEB
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # C7	F1_dam_C7	0	0	0	0	G	T	A	A	G	T	A	G	G	...
    # LINKAGE
    # #java Filtering  data=C07_LSalAtl2sD140.linkage.txt dataTolerance=0.001
    # C7	P0_sir_C7	0	0	1	0	1 1	0 0	1 2	1 2	1 2	1 2	...
    # C7	F1_dam_C7	P0_sir_C7	P0_dam_C7	2 	0	1 2	0 0	2 2	1 2	1 1	1 ...
    while (<$in>)
    {
        next if (m/^#/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data > 8 && defined $data[0] && defined $data[1] && exists $parents_table{$data[1]})
        {
            if ($lepmap3)
            {
                if (!exists $table{$data[1]})                    { $table{$data[1]}                    = ++$last; }
                if (!exists $table{$parents_table{$data[1]}[1]}) { $table{$parents_table{$data[1]}[1]} = ++$last; }
                if (!exists $table{$parents_table{$data[1]}[2]}) { $table{$parents_table{$data[1]}[2]} = ++$last; }
                print $data[0], "\t", $table{$data[1]}, "\t", $table{$parents_table{$data[1]}[1]}, "\t", $table{$parents_table{$data[1]}[2]}, "\t", ($parents_table{$data[1]}[3] =~ /^F/i ? q{2} : ($parents_table{$data[1]}[3] =~ /^M/i ? q{1} : q{0})),
                  "\t0";
                for (my $i = 6 ; $i < scalar @data ; $i = $i + 2)
                {
                    print "\t", (defined $data[$i]     && exists $table{$data[$i]}     ? $table{$data[$i]}     : q{0});
                    print q{ }, (defined $data[$i + 1] && exists $table{$data[$i + 1]} ? $table{$data[$i + 1]} : q{0});
                }
            }
            else
            {
                print $data[0], "\t", $data[1], "\t", $parents_table{$data[1]}[1], "\t", $parents_table{$data[1]}[2], "\t", ($parents_table{$data[1]}[3] =~ /^F/i ? q{2} : ($parents_table{$data[1]}[3] =~ /^M/i ? q{1} : q{0})), "\t0";
                for my $i (6 .. (scalar @data) - 1) { print "\t", (defined $data[$i] && exists $table{$data[$i]} ? $table{$data[$i]} : q{0}); }
            }
            print "\n";
        }
    }
    close $in;
}

#To SNPAssoc
elsif (scalar keys %parents_table > 0 && ($snpassoc || $ade || $arff) && defined $ped && -r $ped && defined $plink && -r $plink && open($in, q{<}, $plink))
{
    my (@list_marker, @mask_marker);

    # PEB
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # C7	F1_dam_C7	0	0	0	0	G	T	A	A	G	T	A	G	G	...
    # plink MAP
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # LSalAtl2s1	19757_13	0	4466
    # LSalAtl2s1	19756_74	0	4550
    # LSalAtl2s1	19491_4	0	106094
    # LSalAtl2s1	19492_81	0	106518
    # LSalAtl2s1	19498_31	0	118987
    # LSalAtl2s1	19749_27	0	381049
    # LEPMAP MAP
    # #java SeparateChromosomes  data=C07_LSalAtl2sD140_f.linkage.txt lodLimit=6.5 sizeLimit=2
    # 0
    # 6
    # 6
    # 6
    # 0
    # 0
    # SNPAssoc
    # id	Sex	Surviving	33	40	60	120	136	157	180
    # F2_C7_073	Female	2	A/A	-	A/B	A/B	A/B	A/B
    # F2_C7_074	Female	2	A/A	-	B/B	A/B	A/B	A/A
    while (<$in>)
    {
        next if (m/^#/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 2 && defined $data[0] && defined $data[1]) { push @list_marker, $data[1]; push @mask_marker, 1 if (defined $genmap || defined $map || defined $selectlist); }
    }
    close $in;
    if (scalar @list_marker > 0 && defined $genmap && -r $genmap && open($in, q{<}, $genmap))
    {
        my $lg;

        # genmap
        # #java OrderMarkers map=mapLOD5_js.txt data=C07_LSalAtl2sD140_f.linkage.txt sexAveraged=1 useKosambi=1
        # #*** LG = 1 likelihood = -5811.6314 with alpha penalty = -5811.6314
        # #marker_number	male_position	female_position	( error_estimate )[ duplicate* OR phases]	C7
        # 1886	0.000	0.000	( 0 )	11
        # 2789	0.270	0.270	( 0 )	11
        # 2749	2.568	2.568	( 0.2398 )	10
        # 4119	3.455	3.455	( 0 )	-1
        print {*STDERR} "Marker\tLG\tPosition\n";
        while (<$in>)
        {
            if (m/^(#|\*)/)
            {
                if (m/LG = (\d+(\.\d+)?)/) { $lg = $1; }
            }
            else
            {
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 3 && defined $data[0] && defined $data[1] && defined $data[2] && exists $list_marker[$data[0] - 1] && defined $lg)
                {
                    undef $mask_marker[$data[0] - 1];
                    print {*STDERR} $list_marker[$data[0] - 1], "\t", $lg, "\t", $data[($female ? 2 : 1)], "\n";
                }
            }
        }
        close $in;
    }
    elsif (scalar @list_marker > 0 && defined $map && -r $map && open($in, q{<}, $map))
    {
        my $i = 0;
        while (<$in>)
        {
            next if (m/^#/);
            chomp;
            if ($_ ne '0') { undef $mask_marker[$i]; }
            $i++;
        }
        close $in;
    }
    if (defined $selectlist) {
        for my $j (0 .. (scalar @list_marker) - 1) {
        	my $tmp = $list_marker[$j];
            if    ($tmp =~ m/^(\d+)_\d+/)       { $tmp = $1; }
            elsif ($tmp =~ m/^(dDocent.*):\d+/) { $tmp = $1; }
            if (exists $selected{$tmp}) {
    	        undef $mask_marker[$j];
    	    }
    	}
    }
    #else { undef @mask_marker; }

    if (scalar @list_marker > 0 && open($in, q{<}, $ped))
    {
        if ($ade)
        {
        	my @group;
        	my %atcg = (A => 1, C => 2, G => 3, T => 4, N => 0, 0 => 0);
            print "Samples";
            for my $j (0 .. (scalar @list_marker) - 1) { print "\t", $list_marker[$j] if (!defined $mask_marker[$j]); }
            print "\n";
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 8 && defined $data[0] && defined $data[1] && exists $parents_table{$data[1]} && exists $parents_table{$data[1]}[4])
                {
                    print $data[1];
                    push @group, $parents_table{$data[1]}[4];
                    my $i = 6;
                    for my $j (0 .. (scalar @list_marker) - 1) {
                        print "\t", (defined $data[$i + $j * 2] && $data[$i + $j * 2] ne q{0} && defined $data[$i + $j * 2 + 1] && $data[$i + $j * 2 + 1] ne q{0} ? $atcg{$data[$i + $j * 2]} . $atcg{$data[$i + $j * 2 + 1]} : "  ")
                          if (!defined $mask_marker[$j]);
                    }
                    print "\n";
                }
            }
            print {*STDERR} 'pop <- c(\'', join("','",@group),"');\n";
        } elsif ($arff) {
            print {*STDOUT} "\@RELATION default\n\n\@ATTRIBUTE id STRING\n\@ATTRIBUTE sex {F,M}\n";
            for my $j (1 .. $count_meta) { print {*STDOUT} "\@ATTRIBUTE phenotype_$j {}\n"; }
            for my $j (0 .. (scalar @list_marker) - 1) { print {*STDOUT} '@ATTRIBUTE ', $list_marker[$j], " {AA,AC,AG,AT,CC,CG,CT,GG,GT,TT}\n", if (!defined $mask_marker[$j]); }
            print {*STDOUT} "\n\@DATA\n";

            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 8 && defined $data[0] && defined $data[1] && exists $parents_table{$data[1]} && $parents_table{$data[1]}[3] =~ /^(M|F)/i)
                {
                    print {*STDOUT} $data[1], q{,}, ($parents_table{$data[1]}[3] =~ /^F/i ? q{F} : ($parents_table{$data[1]}[3] =~ /^M/i ? q{M} : q{?}));
                    for my $j (1 .. $count_meta) { print {*STDOUT} q{,} , (exists $parents_table{$data[1]}[3 + $j] ? $parents_table{$data[1]}[3 + $j] : q{?}) }
                    my $i = 6;
                    for my $j (0 .. (scalar @list_marker) - 1) {
                        print {*STDOUT} q{,}, (defined $data[$i + $j * 2] && $data[$i + $j * 2] ne q{0} && defined $data[$i + $j * 2 + 1] && $data[$i + $j * 2 + 1] ne q{0} ? $data[$i + $j * 2] . $data[$i + $j * 2 + 1] : q{?})
                          if (!defined $mask_marker[$j]);
                    }
                    print "\n";
                }
            }
        
        } else {
            print "id\tsex";
            for my $j (1 .. $count_meta) { print "\tphenotype_$j", }
            for my $j (0 .. (scalar @list_marker) - 1) { print "\t", $list_marker[$j] if (!defined $mask_marker[$j]); }
            print "\n";
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 8 && defined $data[0] && defined $data[1] && exists $parents_table{$data[1]} && $parents_table{$data[1]}[3] =~ /^(M|F)/i)
                {
                    print $data[1], "\t", ($parents_table{$data[1]}[3] =~ /^F/i ? 'Female' : 'Male');
                    for my $j (1 .. $count_meta) { print "\t", (exists $parents_table{$data[1]}[3 + $j] ? $parents_table{$data[1]}[3 + $j] : q{}) }
                    my $i = 6;
                    for my $j (0 .. (scalar @list_marker) - 1) {
                        print "\t", (defined $data[$i + $j * 2] && $data[$i + $j * 2] ne q{0} && defined $data[$i + $j * 2 + 1] && $data[$i + $j * 2 + 1] ne q{0} ? $data[$i + $j * 2] . q{/} . $data[$i + $j * 2 + 1] : q{-})
                          if (!defined $mask_marker[$j]);
                    }
                    print "\n";
                }
            }
        }
        close $in;
    }
}
elsif ($remap && scalar @extra > 0 && defined $genetic && -r $genetic && open($in, q{<}, $genetic))
{
    my (%list_markers, %list2_markers, %list_sequences);
    open(my $seqfile, q{>}, '/tmp/blast_' . $genetic . '.fasta');
    while (<$in>)
    {
        next if (m/^(#|Marker)/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 4 && defined $data[0] && defined $data[1] && defined $data[2] && defined $data[-1])
        {
            @{$list_markers{$data[0]}} = @data;
            print {$seqfile} '>', $data[0], "\n", $data[-1], "\n";
        }
    }
    close $seqfile;
    close $in;
    foreach my $infile (@extra)
    {
        if (defined $infile && -r $infile && open(my $in2, q{<}, $infile))
        {
            #Extra
            # "","comments","codominant"
            # "X67793_33",NA,0.02511912
            while (<$in2>)
            {
                chomp;
                my @data = split m/,/;
                if (scalar @data >= 3 && defined $data[0] && defined $data[2] && $data[2] ne 'NA')
                {
                    if ($data[0] =~ m/X([\d\w\_\.]+)/) { $list2_markers{$1} = 1; }
                    elsif ($data[0] =~ m/(dDocent.*)\.(\d+)/) { $list2_markers{$1 . q{:} . $2} = 1; }
                }
            }
            close $in2;
        }
    }
    my %tmp2_list;
    for my $item (keys %list2_markers)
    {
        if    ($item =~ m/^(\d+)_\d+/)       { $tmp2_list{$1} = $item; $tmp2_list{$item} = $1; }
        elsif ($item =~ m/^(dDocent.*):\d+/) { $tmp2_list{$1} = $item; $tmp2_list{$item} = $1; }
        else                                 { $tmp2_list{$item} = $item; }
    }
    open(my $queryfile, q{>}, '/tmp/query_' . $genetic . '.fasta');
    if (defined $markers && -r $markers)
    {
        my %unique;
        if (defined $ped && -r $ped && defined $plink && -r $plink && open($in, q{<}, $plink))
        {
            my @list_full;
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data >= 2 && defined $data[0] && defined $data[1]) { push @list_full, $data[1]; }
            }
            close $in;
        }
        if (open($in, q{<}, $markers))
        {
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 9 && defined $data[2] && defined $data[9] && exists $tmp2_list{$data[2]}) { print {$queryfile} '>', $tmp2_list{$data[2]}, "\n", $data[9], "\n"; }
            }
            close $in;
        }
    }
    elsif (defined $fasta && -r $fasta)
    {
        if (open($in, q{<}, $fasta))
        {
            my ($seq, $header) = (q{});
            while (<$in>)
            {
                next if /^\s*$/;
                chomp;
                if (/^>/)
                {    # fasta header line
                    my $h = $_;
                    $h =~ s/^>//;
                    if (defined $header && length $seq > 10)
                    {
                        print {$queryfile} '>', $tmp2_list{$header}, "\n", $seq, "\n" if (exists $tmp2_list{$header});
                        $header = $h;
                        $seq    = q{};
                    }
                    else { $header = $h }
                }
                else
                {
                    s/\W+//;
                    $seq .= $_;
                }
            }
            if (defined $header && length $seq > 10) { print {$queryfile} '>', $tmp2_list{$header}, "\n", $seq, "\n" if (exists $tmp2_list{$header}); }
            close $in;
        }
    }
    close $queryfile;
    if (system('makeblastdb -dbtype nucl -in "' . '/tmp/blast_' . $genetic . '.fasta' . '" -parse_seqids -hash_index -out "' . '/tmp/blast_' . $genetic . '_db" >/dev/null') != 0)
    {
        print {*STDERR} "ERROR: makeblastdb failed to execute: $!\n";
        system('rm -f /tmp/query_' . $genetic . '.* /tmp/blast_' . $genetic . '*');
        exit 10;
    }
    if (
        system(
                   'blastn'
                 . ' -query '
                 . '/tmp/query_'
                 . $genetic
                 . '.fasta'
                 . ' -db "'
                 . '/tmp/blast_'
                 . $genetic
                 . '_db" -task blastn -dust yes -outfmt "6 std qlen slen" -max_target_seqs 1'
                 . (int($threads) > 1 ? ' -num_threads ' . int($threads) : q{})
                 . ' -out /tmp/query_'
                 . $genetic
                 . '.blast'
        ) != 0
       )
    {
        print {*STDERR} "ERROR: blastn failed to execute: $!\n";
        system('rm -f /tmp/query_' . $genetic . '.* /tmp/blast_' . $genetic . '*');
        exit 10;
    }
    my %remap;
    if (open($in, q{<}, '/tmp/query_' . $genetic . '.blast'))
    {
        while (<$in>)
        {
            next if (m/^#/);
            chomp;
            my @data = split m/\t/;
            if (scalar @data >= 14 && defined $data[0] && defined $data[1] && defined $data[2] && defined $data[3] && defined $data[12] && defined $data[13])
            {
                # NEED CLEAN UP
                if (int($data[2]) >= 90 && (int($data[3]) == int($data[12]) || int($data[3]) == int($data[13]) || int($data[3]) >= 99))
                {
                    $remap{$data[0]} = $list_markers{$data[1]};
                    print {*STDERR} $data[0], "\t", $list_markers{$data[1]}[0], "\n";
                }
            }
        }
        close $in;
    }
    system('rm -f /tmp/query_' . $genetic . '.* /tmp/blast_' . $genetic . '*');
    print {*STDOUT} "Marker\tLG\tPosition\n";
    for my $item (keys %list2_markers) { print {*STDOUT} $item, "\t", (exists $remap{$item} ? $remap{$item}[1] . "\t" . $remap{$item}[2] : "Unk\t0"), "\n"; }
}
elsif ($tableS && defined $ped && -r $ped && defined $plink && -r $plink && open($in, q{<}, $plink))
{
    my (@list_marker, @samples, %unique, %list_markers, %list_sequences );

    # PEB
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # C7	F1_dam_C7	0	0	0	0	G	T	A	A	G	T	A	G	G	...

    # plink MAP
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # LSalAtl2s1	19757_13	0	4466
    # LSalAtl2s1	19756_74	0	4550
    # LSalAtl2s1	19491_4	0	106094
    # LSalAtl2s1	19492_81	0	106518
    # LSalAtl2s1	19498_31	0	118987
    # LSalAtl2s1	19749_27	0	381049
    while (<$in>)
    {
        next if (m/^#/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 2 && defined $data[0] && defined $data[1]) { @{$list_markers{$data[1]}} = @data; push @list_marker,$data[1]; }
    }
    close $in;

    my %tmp_list;
    for my $item (keys %list_markers)
    {
        if    ($item =~ m/^(\d+)_\d+/)       { $tmp_list{$1} = $item; $tmp_list{$item} = $1; }
        elsif ($item =~ m/^(dDocent.*):\d+/) { $tmp_list{$1} = $item; $tmp_list{$item} = $1; }
        else                                 { $tmp_list{$item} = $item; }
    }
    if (scalar keys %list_markers > 0 && open($in, q{<}, $ped))
    {
                while (<$in>)
                {
                    next if (m/^#/);
                    chomp;
                    my @data = split m/\t/;
                    if (scalar @data > 8)
                    {
                        push @samples, $data[1];
                        for my $j (0 .. (scalar @list_marker) - 1)
                        {
                            if (defined $list_marker[$j] && exists $list_markers{$list_marker[$j]})
                            {
                                if (!exists $unique{$list_marker[$j]}) { $unique{$list_marker[$j]} = q{} }
                                $unique{$list_marker[$j]} .= (defined $data[6 + $j * 2] && $data[6 + $j * 2] ne q{0} && defined $data[6 + $j * 2 + 1] && $data[6 + $j * 2 + 1] ne q{0} ? $data[6 + $j * 2] . $data[6 + $j * 2 + 1] : q{}) . "\t";
                            }
                        }
                    }
                }
                close $in;
    }

    if (defined $markers && -r $markers)
    {

        if (open($in, q{<}, $markers))
        {
            # ## cstacks version 1.42; catalog generated on 2016-09-22 22:24:20
            # 0	2	1	LSalAtl2s1000	1022	-	consensus	0	263_8...	CATGTTTATGTATCATTTGTACTATTATAAAACTGAAATATATATTTTTATGTTTTTGTAAAAATGTTTAATTTATTATCTATAACCATTCCTATTCGCC	0	0	0	0
            # 0	2	2	LSalAtl2s1000	132767	+	consensus	0	263_13...	CATGGTAAATTCGTGGTTTACACTATCATTGTCAGACAAAATTGTTGTGAGTACTATCATCTTGAAGCAATGTCGATGCAAGCAATAAGATTGTAAGTAA	0	0	0	0
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > 9 && defined $data[2] && defined $data[9] && exists $tmp_list{$data[2]})
                {
                    my $snploc;
                    if    ($tmp_list{$data[2]} =~ m/\_(\d+)/)          { $snploc = $1; }
                    elsif ($tmp_list{$data[2]} =~ m/dDocent.*\.(\d+)/) { $snploc = $1; }
                    my $tmp = $unique{$tmp_list{$data[2]}};
                    $tmp =~ s/(.)(?=.*?\1)//g;
                    my $seq = (defined $tmp && defined $snploc ? substr($data[9], 0, $snploc) . q{[} . substr($tmp,0,length($tmp) -1) . q{]} . substr($data[9], $snploc + 1) : $data[9]);
                    $list_sequences{$tmp_list{$data[2]}} = (int($loc) > 0 && defined $data[3] && defined $data[4] ? $data[3] . "\t" . $data[4] . "\t" . $seq : $seq);
                }
            }
            close $in;
        }
    }
    elsif (defined $fasta && -r $fasta)
    {
        if (open($in, q{<}, $fasta))
        {
            # >dDocent_Contig_12
            # TGCAGAAAACACTCTCTCCCCAGACGGGTTTTGATAGAGTAGAACTCCGTCTCGATAGAAAGCAAAGTTGTTATATATATAGTAATAACTAGAGGGATTANNNNNNNNNNCATGTTTAATTTTAAAACATTTTCACACAACCTTAGATGGCTTTTATATTTAATATTCTATTCGAAATTTAAAAGATTTTGTAGCGGTGGATATTTTTGT
            my ($seq, $header) = (q{});
            while (<$in>)
            {
                next if /^\s*$/;
                chomp;
                if (/^>/)
                {    # fasta header line
                    my $h = $_;
                    $h =~ s/^>//;
                    if (defined $header && length $seq > 10)
                    {
                        $list_sequences{$header} = $seq if (exists $tmp_list{$header});
                        $header                  = $h;
                        $seq                     = q{};
                    }
                    else { $header = $h }
                }
                else
                {
                    s/\W+//;
                    $seq .= $_;
                }
            }
            if (defined $header && length $seq > 10) { $list_sequences{$header} = $seq if (exists $tmp_list{$header}); }
            close $in;
        }
    }
    print {*STDOUT} "Marker\t", join("\t", @samples), (defined $markers && -r $markers ? "\t" . 'Details' : (defined $fasta && -r $fasta ? "\t" . 'Marker' : q{})), "\n";
    for my $item (keys %list_markers) {
        if(!%selected || exists $selected{$item}){
            print {*STDOUT} $item, "\t", substr($unique{$item},0,length($unique{$item}) -1), (exists $list_sequences{$item} ? "\t" . $list_sequences{$item} : (exists $tmp_list{$item} && exists $list_sequences{$tmp_list{$item}} ? "\t" . $list_sequences{$tmp_list{$item}} : q{})), "\n";
        }
    }
}
elsif (scalar @extra > 0 && defined $genetic && -r $genetic && open($in, q{<}, $genetic))
{
    my (%list_markers, %list_sequences);

    # genetic
    # Marker	LG	Position
    # 67793_33	1	0.000
    # 65135_20	1	1.561
    # 47811_36	1	4.114
    # 47815_44	1	4.114
    # 11332_62	1	6.270
    # 47683_83	1	6.537
    while (<$in>)
    {
        next if (m/^(#|Marker)/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 2 && defined $data[0] && defined $data[1] && defined $data[2]) { @{$list_markers{$data[0]}} = @data; }
    }
    close $in;
    foreach my $infile (@extra)
    {
        if (defined $infile && -r $infile && open(my $in2, q{<}, $infile))
        {
            my %tmp_list;

            #Extra
            # "","comments","codominant"
            # "X67793_33",NA,0.02511912
            while (<$in2>)
            {
                chomp;
                my @data = split m/,/;
                if (scalar @data >= 3 && defined $data[0] && defined $data[2] && $data[2] ne 'NA')
                {
                    if ($data[0] =~ m/X([\d\w\_\.]+)/) { $tmp_list{$1} = $data[2]; }
                    elsif ($data[0] =~ m/(dDocent.*)\.(\d+)/) { $tmp_list{$1 . q{:} . $2} = $data[2]; }
                }
            }
            close $in2;
            if (scalar keys %tmp_list > 0)
            {
                for my $item (keys %list_markers) { push @{$list_markers{$item}}, (exists $tmp_list{$item} ? ($lod ? -log($tmp_list{$item}) / log(10) : $tmp_list{$item}) : q{-}); }
            }
        }
    }
    my %tmp_list;
    for my $item (keys %list_markers)
    {
        if    ($item =~ m/^(\d+)_\d+/)       { $tmp_list{$1} = $item; $tmp_list{$item} = $1; }
        elsif ($item =~ m/^(dDocent.*):\d+/) { $tmp_list{$1} = $item; $tmp_list{$item} = $1; }
        else                                 { $tmp_list{$item} = $item; }
    }
    if (defined $markers && -r $markers)
    {
        my %unique;
        if (defined $ped && -r $ped && defined $plink && -r $plink && open($in, q{<}, $plink))
        {
            my @list_full;
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data >= 2 && defined $data[0] && defined $data[1]) { push @list_full, $data[1]; }
            }
            close $in;
            if (scalar @list_full > 0 && open($in, q{<}, $ped))
            {
                while (<$in>)
                {
                    next if (m/^#/);
                    chomp;
                    my @data = split m/\t/;
                    if (scalar @data > 8)
                    {
                        for my $j (0 .. (scalar @list_full) - 1)
                        {
                            if (defined $list_full[$j] && exists $list_markers{$list_full[$j]})
                            {
                                if (!exists $unique{$list_full[$j]}) { $unique{$list_full[$j]} = q{} }
                                $unique{$list_full[$j]} .= (defined $data[6 + $j * 2] && $data[6 + $j * 2] ne q{0} && defined $data[6 + $j * 2 + 1] && $data[6 + $j * 2 + 1] ne q{0} ? $data[6 + $j * 2] . $data[6 + $j * 2 + 1] : q{});
                            }
                        }
                    }
                }
                close $in;
            }
        }
        if (open($in, q{<}, $markers))
        {
            # ## cstacks version 1.48; catalog generated on 2018-09-22 22:24:20
            # 0	2	1	LSalAtl2s1000	1022	-	consensus	0	263_8...	CATGTTTATGTATCATTTGTACTATTATAAAACTGAAATATATATTTTTATGTTTTTGTAAAAATGTTTAATTTATTATCTATAACCATTCCTATTCGCC	0	0	0	0
            # 0	2	2	LSalAtl2s1000	132767	+	consensus	0	263_13...	CATGGTAAATTCGTGGTTTACACTATCATTGTCAGACAAAATTGTTGTGAGTACTATCATCTTGAAGCAATGTCGATGCAAGCAATAAGATTGTAAGTAA	0	0	0	0

            # # cstacks version 2.3e; catalog generated on 2019-05-20 16:12:34
            # 0	1	consensus	0	148_1...	CATGCATGTTACTTAAGGGTAGTTTCAGAGGAGCAAGTGGCACATCCCTCCCTCTGCATTTTCAAATGACTGTTGTTGATTTTATTAAAACAAATTCTCCAAATTAAAGTGTAAAATCTTGGTAACCTTTGGAAGTAAAGT	0	0	0
            my $seqpos = 5;
            my $seqid = 1;
            my $line = <$in>;
            if ($line =~ m/version 1/) {
                $seqpos = 9;
                $seqid = 2;
            }
            while (<$in>)
            {
                next if (m/^#/);
                chomp;
                my @data = split m/\t/;
                if (scalar @data > $seqpos && defined $data[$seqid] && defined $data[$seqpos] && exists $tmp_list{$data[$seqid]})
                {
                    my $snploc;
                    if    ($tmp_list{$data[$seqid]} =~ m/\_(\d+)/)          { $snploc = $1; }
                    elsif ($tmp_list{$data[$seqid]} =~ m/dDocent.*\.(\d+)/) { $snploc = $1; }
                    $unique{$tmp_list{$data[$seqid]}} =~ s/(.)(?=.*?\1)//g;
                    my $seq = (exists $unique{$tmp_list{$data[$seqid]}} && defined $snploc ? substr($data[$seqpos], 0, $snploc) . q{[} . $unique{$tmp_list{$data[$seqid]}} . q{]} . substr($data[$seqpos], $snploc + 1) : $data[$seqpos]);

                    # to be check for v2+
                    $list_sequences{$tmp_list{$data[$seqid]}} = (int($loc) > 0 && defined $data[3] && defined $data[4] ? $data[3] . "\t" . $data[4] . "\t" . $seq : $seq);
                }
            }
            close $in;
        }
    }
    elsif (defined $fasta && -r $fasta)
    {
        if (open($in, q{<}, $fasta))
        {
            # >dDocent_Contig_12
            # TGCAGAAAACACTCTCTCCCCAGACGGGTTTTGATAGAGTAGAACTCCGTCTCGATAGAAAGCAAAGTTGTTATATATATAGTAATAACTAGAGGGATTANNNNNNNNNNCATGTTTAATTTTAAAACATTTTCACACAACCTTAGATGGCTTTTATATTTAATATTCTATTCGAAATTTAAAAGATTTTGTAGCGGTGGATATTTTTGT
            my ($seq, $header) = (q{});
            while (<$in>)
            {
                next if /^\s*$/;
                chomp;
                if (/^>/)
                {    # fasta header line
                    my $h = $_;
                    $h =~ s/^>//;
                    $h = $1 if ($h =~ /^(\d+)/mg);
                    if (defined $header && length $seq > 10)
                    {
                        $list_sequences{$tmp_list{$header}} = $seq if (exists $tmp_list{$header});
                        $header                  = $h;
                        $seq                     = q{};
                    }
                    else
                    {
                        $header = $h;
                    }
                }
                else
                {
                    s/\W+//;
                    $seq .= $_;
                }
            }
            if (defined $header && length $seq > 10) { $list_sequences{$header} = $seq if (exists $tmp_list{$header}); }
            close $in;
        }
    }
    print {*STDOUT} "Marker\tLG\tPosition\t", join("\t", @extra), (defined $markers && -r $markers ? "\t" . 'Details' : (defined $fasta && -r $fasta ? "\t" . 'Marker' : q{})), "\n";
    for my $item (keys %list_markers) { print {*STDOUT} join("\t", @{$list_markers{$item}}), (exists $list_sequences{$item} ? "\t" . $list_sequences{$item} : (exists $tmp_list{$item} && exists $list_sequences{$tmp_list{$item}} ? "\t" . $list_sequences{$tmp_list{$item}} : q{})), "\n"; }
}
elsif ($edit && defined $plink && -r $plink && defined $genetic && -r $genetic && open($in, q{<}, $genetic))
{
    my %list_markers;
    while (<$in>)
    {
        next if (m/^(#|Marker)/);
        chomp;
        my @data = split m/\t/;
        if (scalar @data >= 2 && defined $data[0] && defined $data[1]) { $list_markers{$data[0]} = $data[1]; }
    }
    close $in;

    # plink MAP
    # # Stacks v1.42;  PLINK v1.07; October 06, 2016
    # LSalAtl2s1	19757_13	0	4466
    # LSalAtl2s1	19756_74	0	4550
    # LSalAtl2s1	19491_4	0	106094
    # LSalAtl2s1	19492_81	0	106518
    # LSalAtl2s1	19498_31	0	118987
    # LSalAtl2s1	19749_27	0	381049
    if (open $in, q{<}, $plink)
    {
        print {*STDOUT} "# plinktomap edit mode\n";
        while (<$in>)
        {
            next if (m/^#/);
            chomp;
            my @data = split m/\t/;
            print {*STDOUT} (scalar @data >= 2 && exists $list_markers{$data[1]} ? $list_markers{$data[1]} : q{0}), "\n";
        }
        close $in;
    }
}
else
{
    print {*STDERR}
      "..:: RAD-tags to Genetic Map ::..\n\nUsage: $0 [options]\n\n# LepMap pre-processing\n  --lepmap      MANDATORY\n  --ped         MANDATORY\n  --meta        MANDATORY\n\n  STDOUT > LepMap (linkage) input file\n\n# R/SNPAssoc pre-processing\n  --snpassoc    MANDATORY\n  --plink       MANDATORY\n  --ped         MANDATORY\n  --meta        MANDATORY\n  --map         OPTIONAL\n  --gmap        OPTIONAL\n  --female      OPTIONAL\n\n  STDOUT > SNPassoc input file\n  STDERR 2> Genetic Map\n\n# Post GWAS processing\n  --genetic     MANDATORY\n  --extra       MANDATORY (at least once)\n  --markers     OPTIONAL\n  --fasta       OPTIONAL\n  --pos         OPTIONAL\n  --lod         OPTIONAL\n  --ped         OPTIONAL (in association with --plink)\n  --plink         OPTIONAL (in association with --ped)\n\n  STDOUT > Genetic Map\n  \nOptions\n  --meta <pedigree file>\n       The pedigree file consists of on columns 1-4+. The columns are separated by\n       tabs. The columns 1-4 are individual name, father, mother and sex; the next\n       columns are for extra phenotypes: phenotype_1 to phenotype_n. The phenotypes\n       are not required, but will be helpful for the GWAS analysis.\n         sample     father  mother  sex  phenotype_1\n         F1_C2_070  P0_sir  P0_dam  M    30\n         F1_C2_120  P0_sir  P0_dam  F    1\n         P0_dam     0       0       F    -\n         P0_sir     0       0       M    -\n  --plink <plink map file>\n       PLINK MAP file path with full haplotypes.\n  --ped <plink ped file>\n       PLINK PED file path with full haplotypes.\n  --map <mappable markers list>\n       Mappable markers list as generated by LepMap \"SeparateChromosomes\" and\n       \"JoinSingles\" functions.\n  --gmap <ordered markers file>\n       Ordered genetic map generated by LepMap.\n  --genetic <genetic map file>\n       Genetic Map as generated by R/SNPAssoc pre-processing step.\n  --markers <batch_<n>.catalog.tags.tsv file>\n       Path to STACKS catalog.tag file, including marker sequences and positions.\n       (incompatible with --fasta)\n  --fasta <uniq.full.fasta file>\n       Path to dDocent uniq.full.fasta file, including marker sequences. (incompatible\n       with --markers)\n  --extra\n       GWAS results generated by R/SNPassoc (csv format) to be added to the genetic map.\n  --lod\n       Convert the P-value of the GWAS results to LOD (LOD=-log(P-value)/log(10)).\n  --pos\n       Provide the marker chromosome/contig and location. (requires --markers)\n  --female\n       Select the female only map rather than male or average mapping. (requires --gmap)\n  --snpassoc\n       Enable R/SNPAssoc pre-processing.\n  --lepmap\n       Enable LepMap pre-processing.\n\n";
}
