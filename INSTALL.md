# Install data-model-transform
```
git clone https://github.com/setoc/data-model-transform-perl.git model.perl
cd model.perl
```
modify model_schema.xml to specify the data table schema

modify model.pl and run it to test Model.pm

Model.pm creates sqlite database files in the root directory - use sqlite3 shell to examine them.


## Install Perl pre-reqs ( this list is based on ActiveState Perl 5.22.1 )
- Log-Log4perl
- DBIx-Lite
-- SQL-Abstract-More
-- Data-Page
-- DBIx-Connector
-- Params-Validate
-- namespace-clean
-- SQL-Abstract
-- Class-Accessor-Chained
-- B-Hooks-EndOfScope
-- Hash-Merge
-- Test-Deep
-- Moo
-- Test-Warn
-- Variable-Magic
-- Role-Tiny
-- Class-Method-Modifiers
- UUID-Tiny
- Template-Toolkit
-- depends on AppConfig
-- depends on Test-LeakTrace
- Mojolicious
- Module-Starter ( not used in the code but used to create the project skeleton )
-- Module-Install-AuthorTests
-- Path-Class
-- Module-Install
-- Win32-UTCFileTime
-- Module-ScanDeps
-- File-Remove
-- YAML-Tiny
