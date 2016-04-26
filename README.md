# git-subversive [![Build Status](https://secure.travis-ci.org/plicease/App-subversive.png)](http://travis-ci.org/plicease/App-subversive)

Export git to Subversion

# SYNOPSIS

    % git subversive update
    % git subversive set name value
    % git subversive unset name
    % git subversive show [ name ]
    % git subversive --help
    % git subversive --version

# DESCRIPTION

**NOTE**: you almost certainly want `git-svn`, not this.

This program allows you to export your git repository to a Subversion repository.
The problem with `git-svn` is that it treats Subversion as the authoritative
source and you frequently have to rebase.  It is almost always what you want if
you are a git user in a Subversion environment.  We have the problem that for
management reasons we need a Subversion repository copy as as a backup, but
we do everything in `git`.  This is a terrible idea, but I am doing it because
I have to.

In order to export commits to the Subversion repository with the correct
dates, you will need to add a `pre-revprop-change` hook.  Basically put a 
`sh` script in the hooks directory of your Subversion repository with the
name `pre-revprop-change` hook with this content:

    #!/bin/sh
    REPOS="$1"
    REV="$2"
    USER="$3"
    PROPNAME="$4"
    ACTION="$5"
    
    if [ "$ACTION" = "M" -a "$PROPNAME" = "svn:log" ]; then exit 0; fi
    if [ "$ACTION" = "M" -a "$PROPNAME" = "svn:date" ]; then exit 0; fi
    
    echo "Changing revision properties other than svn:log is prohibited" >&2
    exit 1

# SUBCOMMANDS

## update

## set

## unset

## show

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
