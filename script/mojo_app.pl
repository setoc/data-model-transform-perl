#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib" }

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('MojoApp');
