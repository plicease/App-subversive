package App::subversive;

use strict;
use warnings;
use 5.012;
use YAML::XS qw( Dump );

sub update
{
  print Dump([update => @_]);
  exit 22;
}

sub set
{
  print Dump([set => @_]);
  exit 23;
}

sub unset
{
  print Dump([unset => @_]);
  exit 25;
}

sub show
{
  print Dump([show => @_]);
  exit 24;
}

1;
