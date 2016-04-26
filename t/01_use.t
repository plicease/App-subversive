use strict;
use warnings;
use Test::More;
use Test::Script;

use_ok 'App::subversive';
script_compiles_ok 'bin/git-subversive';

done_testing;
