use strict;
use warnings;
use Test::More tests => 1;
use App::subversive;
use File::chdir;
use File::Temp qw( tempdir );
use Capture::Tiny qw( capture );

subtest db => sub {

  local $CWD = tempdir( CLEANUP => 1 );
  note "CWD = $CWD";
  mkdir '.git';

  my %SET;

  subtest 'create db' => sub {
    ok ! -f '.git/subversive.sqlite', 'does not exist yet';
    tie %SET, 'App::subversive::Settings';
    ok   -f '.git/subversive.sqlite', 'db created';
    is_deeply [keys %SET], [], 'no key';
    %SET = ( foo => 1, bar => 2 );
    is_deeply [keys %SET], [qw( bar foo )], 'some keys';
    is $SET{foo}, 1, 'SET.foo = 1';
    is $SET{bar}, 2, 'SET.foo = 2';
    
    tie my %other, 'App::subversive::Settings';
    is $other{foo}, 1, 'other.foo = 1';
    is $other{bar}, 2, 'other.foo = 2';
  };
  
  subtest 'show empty' => sub {
    %SET = ();
    my($out, $err, $ret) = capture {
      App::subversive->show;
    };
    is $out, '', 'out';
    is $ret, 0,  'ret';
  };
  
  subtest 'show values' => sub {
    %SET = ( FOO => 'this is one value', BAR => 'but this one will display first' );
    subtest all => sub {
      my($out, $err, $ret) = capture {
        App::subversive->show;
      };
      is $out, "BAR=but this one will display first\nFOO=this is one value\n", 'output both';
      is $ret, 0, 'ret';
    };
    
    subtest single => sub {
      my($out, $err, $ret) = capture {
        App::subversive->show('FOO');
      };
      is $out, "this is one value\n", 'ouput single';
      is $ret, 0, 'ret';
    };
    
    subtest DNE => sub {
      my($out, $err, $ret) = capture {
        App::subversive->show('BAZ');
      };
      is $out, "", 'no output';
      is $ret, 2, 'ret';
    };
  };
  
  subtest 'set values' => sub {
    subtest valid => sub {
      %SET = ();  
      my($out, $err, $ret) = capture {
        App::subversive->set(FOO => "unicron, why have you punished me?");
      };
      is $out, '', 'no output';
      is $ret, 0, 'ret';
      is $SET{FOO}, 'unicron, why have you punished me?';
    };
    
    subtest 'no value' => sub {
      %SET = ();  
      my($out, $err, $ret) = capture {
        App::subversive->set('FOO');
      };
      # use a like, in case something else naughty decided to
      # spew a warning.
      like $err, qr{usage: git subversive set key value}, 'error';
      is $ret, 2, 'exit';
    };

    subtest 'no nothing' => sub {
      %SET = ();  
      my($out, $err, $ret) = capture {
        App::subversive->set;
      };
      # use a like, in case something else naughty decided to
      # spew a warning.
      like $err, qr{usage: git subversive set key value}, 'error';
      is $ret, 2, 'exit';
    };
  };
  
  subtest 'unset values' => sub {
  
    subtest valid => sub {
      %SET = ( FOO => 'anything', BAR => 'else' );
      my($out, $err, $ret) = capture {
        App::subversive->unset('FOO');
      };
      is $out, '', 'out';
      is $ret, 0, 'ret';
      is $SET{FOO}, undef,  'SET.FOO = undef';
      is $SET{BAR}, 'else', 'SET.BAR = else';
    };

    subtest already => sub {
      %SET = ( BAR => 'else' );
      my($out, $err, $ret) = capture {
        App::subversive->unset('FOO');
      };
      is $out, '', 'out';
      is $ret, 0, 'ret';
      is $SET{FOO}, undef,  'SET.FOO = undef';
      is $SET{BAR}, 'else', 'SET.BAR = else';
    };
    
    subtest invalid => sub {
      %SET = ( FOO => 'anything', BAR => 'else' );
      my($out, $err, $ret) = capture {
        App::subversive->unset;
      };
      is $out, '', 'out';
      like $err, qr{usage: git subversive unset key}, 'error';
      is $ret, 2, 'ret';
      is $SET{FOO}, 'anything',  'SET.FOO = anything';
      is $SET{BAR}, 'else', 'SET.BAR = else';
    };
  
  };

};
