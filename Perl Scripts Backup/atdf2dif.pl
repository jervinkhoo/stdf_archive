#!/usr/bin/perl -w
#!/usr/local/bin/perl -w		# perl 5.8
#!/usr/bin/perl -w				# perl 5.00
#!/usr/bin/perl -d
#
#	atdf2dif.pl [-t testlist.dif] [-s] input1.atdf [input2.atd[f] ...] [out1.dif]
#*************************************************
#  program parses .atdf file and generates
#  .dif file to be sucked into excel
#
#  examples:
#     atdf2dif.pl ick.atdf  		# generates ick.dif
#
#     atdf2dif.pl ick.atdf ack.dif	# generates ack.dif from ick.atdf
#
#     atdf2dif.pl -t ick.dif ack.atdf	# generates ack.dif, with same
#					# first columns as found in ick.dif
#
#     atdf2dif.pl -s -t ick.dif *.atdf all.dif	# generates all.dif, with only
#						# the columns as found in ick.dif
#						# combining all the atdf files
#
#*************************************************
#  written by: dgattrell
#              @
#              da-test.com
#  v1 - 26jul2006
#     - converted from atdf2xls.pl version 3 which
#       generated .csv files.  
#     - added statistics header rows (.dif allows  
#       formulas, that's why the switch from .csv
#     - added first column "Sort" to allow multiple
#       header rows to stay at the top when sorting
#       in Excel.
#    - extract scaling factor, scale things
#
# future features...
#    - parse stdf files directly, not atdf
#
#*************************************************
#  parse atdf file:
#	PRR: get device number
#	PTR: get value,testname,testnum (assume unique)
#*************************************************


undef @tnames;		# $tnames[$col]
undef %cols;		# $cols{$tname}
undef @tnums;		# $tnums[$col]
undef @values;		# $values[$col][$row]
undef @devnums;		# $devnums[$row]	  (PRR counter)

undef @low_limits;	# $low_limits[$col]
undef @high_limits;	# $high_limits[$col]
undef @all_units;	# $all_units[$col]

undef $testlist;	# file containing header line of csv file
undef $outfile;		# name of output file..
undef @filenames;	

$row = 0;
$col = 0;

$short_testlist_flag = 0;

@alphabet = ('A','B','C','D','E','F','G','H','I','J','K','L','M','N',
		'O','P','Q','R','S','T','U','V','W','X','Y','Z');


$debug1 = 0;



# process command line
#*************************
while (@ARGV) {
	$arg = shift @ARGV;
	if ($arg =~ /^-t/) {
		$arg = shift @ARGV;
		$testlist = $arg;
	} elsif ($arg =~ /^-h/) {
		print("atdf2dif.pl [-t testlist.dif] [-s] input1.atdf");
		print(" [input2.atd[f] ...] [out1.dif]\n");
		print("    -t use testlist form specified file \n");
		print("    -s shortlist, don't append new tests to testlist \n");
		print("\n");
	} elsif ($arg =~ /^-s/) {
		$short_testlist_flag = 1;
	} elsif ($arg =~ /dif$/) {
		$outfile = $arg;
	} else {
		if (defined(@filenames)) {
			push(@filenames,$arg);
		} else {
			$filenames[0] = $arg;
		}
	}
}



#check that we can read and write the desired files
#*****************************************************
if (! defined($outfile)) {
	$outfile = $filenames[0];
	$outfile =~ s/atdf?$//;	# strip off atd or atdf ending
	$outfile = ">" . $outfile . "dif";
} else {
	if ($outfile =~ /^[^>]/) {
		$outfile = ">" . $outfile;
	}
}
open(DIF,$outfile) || die "Couldn't write $outfile";

if (defined($testlist)) {
	open(LIST,"<$testlist") || die "Couldn't read $testlist";

	# might as well parse it now too...
	#**************************************
	chop($line = <LIST>);		# grab first line...
	while ($line !~ /^BOT/) {
		chop($line = <LIST>);
	}
	chop($line = <LIST>);		# grab 1,0
	chop($line = <LIST>);		# grab "Sort"
	chop($line = <LIST>);		# grab 1,0
	chop($line = <LIST>);		# grab "Device"
	chop($line = <LIST>);		# grab 1,0
	chop($line = <LIST>);		# grab "First testname"
	while (($line !~ /^BOT/) && ($line !~ /^EOD/)) {
		$line =~ s/"//g;		# remove quotes
		push(@tnames ,$line);
		
		chop($line = <LIST>);
		chop($line = <LIST>);
	}
	for ($col=0;$col<=$#tnames;$col++) {
		$tname = $tnames[$col];
		$cols{$tname} = $col;
	}
	if ($debug1) {
		print("$col tests found in testlist.dif \n");
		print("... $tnames[0] , $tnames[1] , $tnames[2] , ... $tnames[$col-1] \n");
	}
	close(LIST);
		
} else {
	$short_testlist_flag = 0;	
}


# process input atdf files
#*************************
foreach $filename (@filenames) {
	open(ATDF,"<$filename") || die "Couldn't read $filename";

	while (<ATDF>) {
		if (s/^PRR://) {
			# remove CR at end of line if there...
			$_ =~ s/\s$//;
			@fields = split(/\|/,$_);
			$devnum = $fields[2];
			
			# soft bin information
			#------------------------------------
			$sbin = $fields[6];
			$tname  = "SOFT_BIN";
			$value = $sbin;
			$search = "^" . $tname . "\$";
			@found = grep(/$search/,@tnames);
			if ($#found>=0) {
				$col = $cols{$tname};
			} elsif(! $short_testlist_flag) {
				$col = $#tnames + 1;
				$tnames[$col]=$tname;
				$cols{$tname}=$col;
			}
			if (!$short_testlist_flag || ($#found>=0) ) {
				$values[$col][$row] = $value;
				if (!defined($low_limits[$col])) {
					$low_limits[$col]="";
					$high_limits[$col]="";
					$all_units[$col]="";
				}
			}

			# hard bin information
			#------------------------------------
			$hbin = $fields[5];
			$tname  = "HARD_BIN";
			$value = $hbin;
			$search = "^" . $tname . "\$";
			@found = grep(/$search/,@tnames);
			if ($#found>=0) {
				$col = $cols{$tname};
			} elsif(! $short_testlist_flag) {
				$col = $#tnames + 1;
				$tnames[$col]=$tname;
				$cols{$tname}=$col;
			}
			if (!$short_testlist_flag || ($#found>=0) ) {
				$values[$col][$row] = $value;
				if (!defined($low_limits[$col])) {
					$low_limits[$col]="";
					$high_limits[$col]="";
					$all_units[$col]="";
				}
			}

			# test execution time
			#----------------------------------------
			$testtime = $fields[11]/1000.0;
			$tname = "TEST_TIME";
			$value = $testtime;
			$search = "^" . $tname . "\$";
			@found = grep(/$search/,@tnames);
			if ($#found>=0) {
				$col = $cols{$tname};
			} elsif(! $short_testlist_flag) {
				$col = $#tnames + 1;
				$tnames[$col]=$tname;
				$cols{$tname}=$col;
			}
			if (!$short_testlist_flag || ($#found>=0) ) {
				$values[$col][$row] = $value;
				if (!defined($low_limits[$col])) {
					$low_limits[$col]="";
					$high_limits[$col]="";
					$all_units[$col]="S";
				}
			}


			$devnums[$row] = $devnum;
			$row++;
		} elsif (s/^PTR://) {
			if ($_ =~ /\|$/) {
				# PTR is split over 2 lines, need to merge...
				$line1 = $_;
				$line1 =~ s/\n$//;
				$line2 = <ATDF>;
				$line2 =~ s/^\s//;
				$_ = $line1 . $line2;
			}
			@fields = split(/\|/,$_);
			$tnum = $fields[0];
			$value = $fields[3];
			$tname = $fields[6];
			$tname =~ s#/$##;	# remove bogus '/' at end of testname
			$units = $fields[9];
			$lolim = $fields[10];
			$hilim = $fields[11];
			$scale = $fields[17];
			
			# print("PTR field count: $#fields, scale is $scale \n");
			($prefix,$multiplier) = &scale_info($scale);
			$units = $prefix . $units;
			$value = $value * $multiplier;
			if ($lolim =~ /^\d+/) {
				$lolim = $lolim * $multiplier;
			}
			if ($hilim =~ /^\d+/) {
				$hilim = $hilim * $multiplier;
			}
			
			
			# have we seen this test before?
			#*******************************
			$search = "^" . $tname . "\$";
			@found = grep(/$search/,@tnames);
			if ($#found>=0) {
				$col = $cols{$tname};
			} elsif(! $short_testlist_flag) {
				$col = $#tnames + 1;
				$tnames[$col]=$tname;
				$cols{$tname}=$col;
				
			}

			if (!$short_testlist_flag || ($#found>=0) ) {
				$values[$col][$row] = $value;
				if (!defined($low_limits[$col])) {
					$low_limits[$col]=$lolim;
					$high_limits[$col]=$hilim;
					$all_units[$col]=$units;
					
					if ($debug1) {
						print("Test $tnames[$col] at col $col ll= $lolim ul=$hilim units=$units \n");
					}
				}
			}
		} else {
			# ignore this record...
		}
	}
}
$max_row = $row;
$max_col = $#tnames+1;


# for the DIF file, we need to know ahead of time how big the table is...
#************************************************************************
# rows = data rows + 11 header rows (tname, units, ll, ul, min, mean, max...)
# columns = test columns + sort and device column
print(DIF "TABLE\n0,1\n\"EXCEL\"\n");
$y = $max_row + 11;
print(DIF "VECTORS\n0,$y\n\"\"\n");
$x = $max_col + 2;
print(DIF "TUPLES\n0,$x\n\"\"\n");


# now print out the Testname header line to the .dif file
#*********************************************************
print(DIF "DATA\n0,0\n\"\"\n-1,0\nBOT\n");
print(DIF "1,0\n\"Sort\"\n");
print(DIF "1,0\n\"Device\"\n");
for ($col=0;$col<$max_col;$col++) {
	print(DIF "1,0\n\"$tnames[$col]\"\n");
}


# now print out the units header line to the .dif file
#*********************************************************
print(DIF "-1,0\nBOT\n");
print(DIF "0,1\nV\n1,0\n\"units\"\n");
for ($col=0;$col<$max_col;$col++) {
	print(DIF "1,0\n\"$all_units[$col]\"\n");
}


# now print out the limits lines to the .dif file
#*************************************************
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.1\nV\n1,0\n\"low_limit\"\n");
for ($col=0;$col<$max_col;$col++) {
	if( !defined($low_limits[$col]) ) {
		print("undefined limit at col $col, $tnames[$col] \n");
		$low_limits[$col] = "";
		$high_limits[$col] = "";
	}
	print(DIF "0,$low_limits[$col]\nV\n");
}


print(DIF "-1,0\nBOT\n");
print(DIF "0,1.2\nV\n1,0\n\"high_limit\"\n");
for ($col=0;$col<$max_col;$col++) {
	print(DIF "0,$high_limits[$col]\nV\n");
}


# now print out the statistics lines to the .dif file
#*****************************************************
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.3\nV\n1,0\n\"min\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=MIN\($c","12\:$c$y\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.4\nV\n1,0\n\"mean\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=AVERAGE\($c","12\:$c$y\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.5\nV\n1,0\n\"max\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=MAX\($c","12\:$c$y\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.6\nV\n1,0\n\"std dev\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=STDEV\($c","12\:$c$y\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.7\nV\n1,0\n\"cpk_lo\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=\($c","6-$c","3\)/\(3\*$c","8\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.8\nV\n1,0\n\"cpk_hi\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=\($c"."4-$c"."6\)/\(3\*$c"."8\)\"\n");
}
print(DIF "-1,0\nBOT\n");
print(DIF "0,1.9\nV\n1,0\n\"count\"\n");
for ($col=0;$col<$max_col;$col++) {
	$c = &column_char($col+2);
	print(DIF "1,0\n\"=COUNT\($c"."12\:$c$y\)\"\n");
}


# now print out the data lines to the .dif file
#************************************************
for ($row=0;$row<$max_row;$row++) {
	print(DIF "-1,0\nBOT\n");
	print(DIF "0,2\nV\n0,$devnums[$row]\nV\n");
	for ($col=0;$col<$max_col;$col++) {
		if (defined($values[$col][$row])) {
			print(DIF "0,$values[$col][$row]\nV\n");
		} else {
			print(DIF "1,0\n\"\"\n");
		}
	}
}
print(DIF "-1,0\nEOD\n");
close DIF;




# just to hide warnings...
#****************************
$bogus=$tnum;
$bogus=$tnums;


#===================================================
# SUBROUTINES
#===================================================
sub column_char {
	local($col) = pop(@_);

	if ($col>255) {
		print("WARNING: excel likes <256 columns: column $col+1 \n");
	}
	if ($col<26) {
		$char = $alphabet[$col];
	} else {
		$col2 = int($col/26);
		$col = $col - (26*$col2);
		$char = $alphabet[$col2-1] . $alphabet[$col];
	}

	$char;	# return the character string...
}



#===================================================
sub scale_info {
	local($scaler) = pop(@_);
	
	$char = '';
	$mult = 1.0;
	SWITCH: {
		if ($scaler == -9) { $char = 'G'; $mult = 1.0e-9; last SWITCH; }
		if ($scaler == -6) { $char = 'M'; $mult = 1.0e-6; last SWITCH; }
		if ($scaler == -3) { $char = 'K'; $mult = 1.0e-3; last SWITCH; }
		if ($scaler ==  3) { $char = 'm'; $mult = 1.0e3;  last SWITCH; }
		if ($scaler ==  6) { $char = 'u'; $mult = 1.0e6;  last SWITCH; }
		if ($scaler ==  9) { $char = 'n'; $mult = 1.0e9;  last SWITCH; }
		if ($scaler == 12) { $char = 'p'; $mult = 1.0e12; last SWITCH; }
		if ($scaler == 15) { $char = 'f'; $mult = 1.0e15; last SWITCH; }
	}
	($char, $mult);
}
