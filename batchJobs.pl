#!/usr/bin/perl
use strict;
use warnings;
use threads;

my $batchFile = shift;

if (!$batchFile) {
  print STDERR " Usage: batchJobs.pl <Batch File>\n\n";
  exit 1;
}

# Get jobs
print " Job list... \n";
my @jobs;
open (JOBS, $batchFile) or die " Cannot open $batchFile: $!\n\n";
while (my $cmd = <JOBS>) {
  # Skip comments and blank lines
	$cmd =~ s/^\s+//;
  next if (substr($cmd,0,1) eq '#' || $cmd =~ /^\s*$/);
  print "\t".$cmd;
  chomp $cmd;
  push @jobs, $cmd;
}
close JOBS;

# Check with user to make sure this is what they want
print " Do you want to start these jobs? (y / n) ";
my $response = <STDIN>;
chomp $response;
if ($response ne 'y') {
  print " Okay, stopping...\n\n";
  exit 1;
}

# Start jobs
print " Running jobs... \n";
my @threads;
foreach my $cmd (@jobs) {
  # Add command to stack
  my $thr = threads->new('start_thread',$cmd);
  push @threads, $thr;
}

foreach my $thr (@threads) {
  $thr->join;
}
exit;

sub start_thread {
  my $job = shift;
  print "\t".$job."\n";
  `$job`;
}
