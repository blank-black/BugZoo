#!/usr/bin/perl -w
#
# Compilation script for repair scenarios
# 
# USAGE: 
# perl compile.pl __EXE_NAME__ 
# 
# In normal usage __EXE_NAME__ is actually a directory containing the files to
# repair. We first read in $project_list, then look for each file therein
# and copy them to the proper folder in the $project directory. Then we run
# make etc.
# 
# NOTE:
# Surely this doesn't support multiple evaluations? This isn't thread-safe.

use strict;
use File::Basename;
use Cwd;
use Cwd 'abs_path';

# Remember the PWD.
my $pwd = getcwd();

# Find the directory where this script resides, this directory should also
# hold the original program under repair within one of its sub-directories.
my $script_dir = dirname(abs_path($0));
my $project_name = "libtiff";
my $project = "$script_dir/$project_name";
my $project_list = "program.txt";

# Retrieve the location of the repaired program files.
# Flatten the path to remove /./'s
$ARGV[0]  =~ s/\/[.]\//\//g;
my $subdir = dirname($ARGV[0]);
my $subdir_len = length($subdir) + 1;
my $subdir_base = basename($subdir);

sub say {
    my $msg = $_[0];
    print STDERR "|[$0]|: $msg \n";
}

# Prints a given command before executing it, and reports if the command
# failed.
sub execute 
{
    my $cmd = $_[0];
    print "$cmd\n";
    (system($cmd) != 0) && (say "Command '$cmd' failed: $!");
}

sub retry_python_build() {
    say "FAILED TO COMPILE PYTHON";
    say "TRYING AGAIN, THIS MIGHT TAKE AWHILE!";
    my $result = system("make clean 2>&1");
    if ($result != 0)
    {
        my $remake = system("make 2>&1");
        if ($remake != 0) { say "DIDNT WORK, DYING"; exit 1; }
        else { say "WORKED!"; exit 0; }
    }
    else
    {
        say "Failed to make clean, dying";
        exit 1;
    }
}

sub make
{
    # PHP specific handling.
    my $is_php = ($project_name =~ "php");
    ($is_php) && system("rm ./sapi/cli/php");
    
    ## Attempt to execute make.
    my $res = system("make 2>&1");

    # Python is picky when it comes to coverage instrumentation, sometimes
    # this will fix it
    if ($res != 0 && ($project_name =~ m/python/) && ($subdir =~ m/coverage/))
    {
        retry_python_build();
    }
    elsif ($res == 0)
    {
        exit 0;
    }
    elsif ($is_php && (-f "./sapi/cli/php"))
    {
        exit 0;
    }
    exit 1;
}

# Read the list of modified files from program.txt into a list.
open(FILE, "$script_dir/$project_list");
my @file_list = <FILE>;
chomp @file_list;
# double % preserves % for scripter.py
my %pfiles= map { $_, 1 } @file_list;
close(FILE);
my @filtered = ();

# Find each repaired source file within the given directory and copy it across
# to the appropriate location in the project directory.
foreach my $file (`find $subdir`)
{
    chomp $file;
    if (-f $file && ! ($file =~ m/.*coverage[.]path.*/))
    {
        $file = substr($file, $subdir_len);
        print "Fixed to: $file\n";
        push(@filtered, $file);
        (-f "$subdir/$file") or die "Invalid file to copy: $subdir/$file";
        execute("cp $subdir/$file $project/$file");
    } 
}

print "Repair files: @file_list \n";
print "Allfiles: @filtered\n";

# Change directory to the project directory, which should now contain the
# modified program files. Proceed to make the project, before returning to
# the original PWD when the script was called.
chdir $project or die "fail chdir $project: $!";
system("killall $project &> /dev/null");
make();
chdir $pwd or die "failed chdir $pwd: $!";