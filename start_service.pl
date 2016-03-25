#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use WS;

# start the server on port 8080
 #my $pid = WS->new(8080)->background();
 #print "Use 'kill $pid' to stop server.\n";
 WS->init();
 WS->run();