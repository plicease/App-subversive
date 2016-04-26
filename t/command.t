use strict;
use warnings;
use Test::More;
use Test::Script;
use YAML::XS qw( Load );
use lib 'corpus/commandtest/lib';

script_runs [ 'bin/git-subversive', '--version' ], { exit => 1 }, '--version';
script_stdout_like qr{^App::subversive version }, 'version output';

script_runs [ 'bin/git-subversive', '--help' ], { exit => 1, stdout => \my $stdout }, '--help';
isnt $stdout, '', 'help output not empty';
note $stdout;

script_runs [ 'bin/git-subversive', '-h' ], { exit => 1, stdout => \($stdout='') }, '-h';
isnt $stdout, '', 'help output not empty';
note $stdout;

script_runs [ 'bin/git-subversive', 'foo' ], { exit => 1 }, 'bad command';
script_stderr_is "unknown command foo\n";

script_runs [ 'bin/git-subversive', qw( update foo bar baz ) ], { exit => 22, stdout => \($stdout='') }, 'update';
is_deeply Load($stdout), [qw( update App::subversive foo bar baz )], 'script got input';

script_runs [ 'bin/git-subversive', qw( set foo bar baz ) ], { exit => 23, stdout => \($stdout='') }, 'set';
is_deeply Load($stdout), [qw( set App::subversive foo bar baz )], 'script got input';

script_runs [ 'bin/git-subversive', qw( show foo bar baz ) ], { exit => 24, stdout => \($stdout='') }, 'show';
is_deeply Load($stdout), [qw( show App::subversive foo bar baz )], 'script got input';

script_runs [ 'bin/git-subversive', qw( unset foo bar baz ) ], { exit => 25, stdout => \($stdout='') }, 'unset';
is_deeply Load($stdout), [qw( unset App::subversive foo bar baz )], 'script got input';

done_testing;
