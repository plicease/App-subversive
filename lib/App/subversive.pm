package App::subversive;

use strict;
use warnings;
use 5.012;
use Path::Class qw( dir file );
use File::Temp qw( tempdir );
use File::chdir;
use Capture::Tiny qw( capture );
use Git::Wrapper;
use File::Find ();
use File::Copy qw( cp );
use Email::Address;

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
  use autodie;

  unless(defined $SET{SUBVERSION_URL})
  {
    say STDERR "please set SUBVERSION_URL";
    exit 2;
  }
  
  my $root = dir( tempdir( CLEANUP => 0 ) );
  say "root = $root";

  svn('checkout', $SET{SUBVERSION_URL}, $root->subdir('svn'));
  
  unless(-d $root->subdir('svn'))
  {
    say STDERR "sub version checkout failed";
    exit 2;
  }
  
  if($SET{SUBVERSION_LASTDATE})
  {
    local $CWD = $root->subdir('svn');
    svn('propset', 'svn:date', '--revprop', -r => 'HEAD', $SET{SUBVERSION_LASTDATE});
    delete $SET{SUBVERSION_LASTDATE};
  }
  
  my $git = Git::Wrapper->new($root->subdir('git'));
  $git->clone($CWD, $git->dir);

  my $commit_start = $SET{GIT_COMMIT};
  
  foreach my $log (reverse $git->log('--date=iso'))
  {
    if(defined $commit_start)
    {
      if($commit_start eq $log->id)
      {
        undef $commit_start;
      }
      next;
    }
    my $date = $log->date;
    $date =~ s/ /T/;
    $date =~ s/ .*$/.0Z/;
    say "@{[ $log->id ]} $date @{[ [split /\n/, $log->message]->[0] ]}";
    $git->checkout($log->id);

    local $CWD = $git->dir;
    
    my @git_files;
    File::Find::find(sub {
      return unless -f $_;
      my $file = file($File::Find::name);
      return if ($file->components)[0] eq '.git';
      push @git_files, $file;
    }, '.');
    
    $CWD = $root->subdir('svn');
    
    my @svn_dirs;
    File::Find::find(sub {

      if(-f $_)
      {
        my $file = file($File::Find::name);
        return if grep /^\.svn$/, $file->components;
        unlink $_;
      }
      else
      {
        my $dir = dir($File::Find::name);
        return if grep /^\.svn$/, $dir->components;
        push @svn_dirs, $dir;
      }
    }, '.');
    
    my %exe = map { s/ - \*$//; $_ => 1 } split /\n/, svn('propget', 'svn:executable', '-R');
    
    foreach my $file (@git_files)
    {
      $DB::single = 1;
      my $git_file = $root->subdir('git')->file($file);
      $file->parent->mkpath(0, 0700) unless -d $file->parent;
      cp($git_file => $file) || die "Copy failed for $git_file => $file: $!";
      svn('add', '--force', '--parents', $file);
      
      if(-x $file && !$exe{"$file"})
      {
        svn('propset', 'svn:executable', 'on', $file);
      }
      if((! -x $file) && $exe{"$file"})
      {
        if($exe{"$file"})
        {
          svn('propdel', 'svn:executable', $file);
        }
      }
    }
    
    my $username = [Email::Address->parse($log->author)]->[0]->address;
    unless($username)
    {
      say STDERR "unable to parse email address from @{[ $log->author ]}";
      exit 2;
    }
    
    foreach my $status_line (split /\n/, svn('status'))
    {
      if($status_line =~ /^!\s+(.*)$/)
      {
        my $file = $1;
        svn('rm', '--force' => $file);
      }
    }
    
    while(my @empty = find_empty())
    {
      svn('rm', '--force' => @empty);
    }

    svn('commit', 
      -m => $log->message . "\n\ngit commit: @{[ $log->id ]}", 
      '--username' => $username,
    );
    $SET{GIT_COMMIT} = $log->id;
    
    eval { svn('propset', 'svn:date', '--revprop', -r => 'HEAD', $date) };
    if(my $error = $@)
    {
      $SET{SUBVERSION_LASTDATE} = $date;
      die $error;
    }
  }
  
  0;
}

sub find_empty
{
  my @empty;
  File::Find::find(sub {
    return unless -d $_;
    my $dir = dir($File::Find::name);
    return if grep /^\.svn$/, $dir->components;
    unless(grep !/^\.svn$/, dir($_)->children)
    {
      push @empty, $dir;
    }
  }, '.');
  @empty;
}

sub svn
{
  my(@command) = @_;
  
  $SET{SUBVERSION_COMMAND} //= 'svn';

  my($out, $err, $ret) = capture {
    system $SET{SUBVERSION_COMMAND}, @command;
  };
  
  if($? != 0)
  {
    say "[out]\n$out" if $out ne '';
    say "[err]\n$err" if $err ne '';
    say "ret = $ret";
    die "command failed: svn @command";
  }
  
  defined wantarray ? $out : ();
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
    say STDERR "please run for git project root";
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
