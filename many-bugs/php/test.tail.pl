);

my $executable = Cwd::abs_path($ARGV[0]);
my $test_name = $tests[$ARGV[1] - 1];
my $here_dir = Cwd::abs_path(dirname(__FILE__));

my $cmd = "./sapi/cli/php ../php-helper.php -p ./sapi/cli/php -q $test_name";
print "$cmd\n";
my $res = system("$cmd");
if ($res == 0) {
  exit 0;
} else {
  exit 1;
}