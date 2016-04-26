package App::subversive;

use strict;
use warnings;
use 5.012;

# ABSTRACT: Export git to Subversion
# VERSION

=head1 SYNOPSIS

 % perldoc git-subversive

=head1 DESCRIPTION

This module contains the machinery for the L<git-subversive> program.

=head1 SEE ALSO

L<git-subversive>

=cut

my %SET;

sub setup
{
  tie %SET, 'App::subversive::Settings';
}

sub update
{
  setup();
  0;
}

sub set
{
  setup();
  my(undef, $key, $value) = @_;
  
  unless(defined $key && defined $value)
  {
    say STDERR "usage: git subversive set key value";
    return 2;
  }
  
  $SET{$key} = $value;
  
  0;
}

sub unset
{
  setup();
  my(undef, $key) = @_;
  
  unless(defined $key)
  {
    say STDERR "usage: git subversive unset key";
    return 2;
  }
  
  delete $SET{$key};
  
  0;
}

sub show
{
  my(undef, $key) = @_;
  setup();
  if(defined $key)
  {
    my $value = $SET{$key};
    if(defined $value)
    {
      say $value;
    }
    else
    {
      return 2;
    }
  }
  else
  {
    foreach my $key (keys %SET)
    {
      say "$key=$SET{$key}";
    }
  }
  0;
}

package App::subversive::Settings;

use DBI;

sub TIEHASH
{
  my($class) = @_;
  
  unless(-d '.git')
  {
    print STDERR "please run for git project root\n";
    exit 2;
  }
  
  my $dbh = DBI->connect('dbi:SQLite:.git/subversive.sqlite', '', '');
  $dbh->do(qq(
    CREATE TABLE IF NOT EXISTS settings (
      "key" NOT NULL PRIMARY KEY UNIQUE,
      "value" NOT NULL
    )
  ));
  
  bless [ $dbh ], $class;
}

sub FETCH
{
  my($self, $key) = @_;
  my $sth = $self->[0]->prepare(q( SELECT value FROM settings WHERE key = ? ));
  $sth->execute($key);
  my $h = $sth->fetchrow_hashref;
  defined $h ? $h->{value} : undef;
}

sub STORE
{
  my($self, $key, $value) = @_;
  $self->[0]->do(q( REPLACE INTO settings ("key", "value") VALUES (?,?) ), {}, $key, $value);
  ();
}

sub DELETE
{
  my($self, $key) = @_;
  $self->[0]->do(q( DELETE FROM settings WHERE "key" = ? ), {}, $key);
  ();
}

sub CLEAR
{
  my($self, $key) = @_;
  $self->[0]->do(q( DELETE FROM settings ));
  ();
}

sub EXISTS
{
  my($self, $key) = @_;
  defined FETCH($self,$key);
}

sub FIRSTKEY
{
  my($self) = @_;
  ($self->[1] = $self->[0]->prepare(q( SELECT "key" FROM settings ORDER BY "key" )))->execute;
  NEXTKEY($self);
}

sub NEXTKEY
{
  my($self) = @_;
  my $h = $self->[1]->fetchrow_hashref;
  defined $h ? $h->{key} : undef;
}

1;
