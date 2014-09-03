#!/usr/bin/perl
use strict;
use warnings;
use threads;
use Thread::Queue;
use Getopt::Std;
use Time::Local;
use POSIX qw(strftime);

my (%opt, $batchFile, $threads, $email);
getopts('t:f:e:hq', \%opt);
arg_check();

################################################################################
# Begin main
################################################################################
## Job start time
my $start_time = strftime("%Y-%m-%d_%H:%M:%S", localtime());

# Read jobs from file
###########################################
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
###########################################

# Check with user to make sure this is what they want
###########################################
if (!$opt{'q'}) {
	print " Do you want to start these jobs? (y / n) ";
	my $response = <STDIN>;
	chomp $response;
	if ($response ne 'y') {
		print " Okay, stopping...\n\n";
		exit 1;
	}
}
###########################################

# Initialize and run threads
###########################################
my $jobq = Thread::Queue->new();
my $resultq = Thread::Queue->new();
# Enqueue jobs
foreach my $job (@jobs) {
  $jobq->enqueue($job);
}
# Enqueue exits
for (my $t = 1; $t <= $threads; $t++) {
  $jobq->enqueue("EXIT");
}
# Create thread pool
for (my $t = 1; $t <= $threads; $t++) {
  threads->create("process");
}
###########################################

# Dequeue data from the results queue
###########################################
while (threads->list(threads::running)) {
  while ($resultq->pending) {
    my $result = $resultq->dequeue();
  }
  sleep 2;
}
while ($resultq->pending) {
  my $result = $resultq->dequeue();
}

## Job end time
my $end_time = strftime("%Y-%m-%d_%H:%M:%S", localtime());

# Notify user
###########################################
if ($email) {
	#my $server = system('hostname');
	#chomp $server;
	system('echo "Job start: '.$start_time.'" | mailx -s "Your job is done" '."'$email'");
}

###########################################

exit;
################################################################################
# End main
################################################################################

################################################################################
# Begin functions
################################################################################

########################################
# Function: process
#   Execute jobs
########################################
sub process {
  while (my $job = $jobq->dequeue()) {
    last if ($job eq 'EXIT');
		system($job);
    $resultq->enqueue('finished');
  }
  threads->detach();
}

########################################
# Function: arg_check
#   Evaluates input arguments
########################################
sub arg_check {
  if ($opt{'h'}) {
    arg_error();
  }
  if ($opt{'f'}) {
    $batchFile = $opt{'f'};
  } else {
    arg_error("An input file is required!");
  }
  if ($opt{'t'}) {
    $threads = $opt{'t'};
  } else {
    $threads = 1;
  }
  if ($opt{'e'}) {
    $email = $opt{'e'};
  }
}

########################################
# Function: arg_error
#   Prints error messages and usage instructions
########################################
sub arg_error {
  my $error = shift;
  if ($error) {
    print STDERR $error."\n";
  }
  my $usage = "
usage: batchJobs.pl -f FILE [-p EMAIL] [-t THREADS] [-q] [-h]

Multi-threaded execution of shell jobs

arguments:
  -f FILE               Input file with one shell job per line.
  -t THREADS            Number of job execution threads.
  -e EMAIL              Email address for job completion notification.
  -q                    Quiet mode.
  -h                    Show this help message and exit.

  ";
  print STDERR $usage;
  exit 1;
}

################################################################################
# End functions
################################################################################
