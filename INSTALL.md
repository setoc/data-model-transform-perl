# Install data-model-transform
```
git clone https://github.com/setoc/data-model-transform-perl.git model.perl
cd model.perl
```
modify model_schema.xml to specify the data table schema

modify model.pl and run it to test Model.pm

Model.pm creates sqlite database files in the root directory - use sqlite3 shell to examine them.


## Install Perl pre-reqs
- Log-Log4perl
- DBIx-Lite
-- DBIx-Lite depends on SQL-Abstract-More
-- DBIx-Lite depends on Data-Page
-- DBIx-Lite depends on DBIx-Connector
-- DBIx-Lite depends on Params-Validate
-- DBIx-Lite depends on namespace-clean
-- DBIx-Lite depends on SQL-Abstract
-- DBIx-Lite depends on Class-Accessor-Chained
-- DBIx-Lite depends on B-Hooks-EndOfScope
-- DBIx-Lite depends on Hash-Merge
-- DBIx-Lite depends on Test-Deep
-- DBIx-Lite depends on Moo
-- DBIx-Lite depends on Test-Warn
-- DBIx-Lite depends on Variable-Magic
-- DBIx-Lite depends on Role-Tiny
-- DBIx-Lite depends on Class-Method-Modifiers
- UUID-Tiny
- Template-Toolkit
-- Template-Toolkit depends on AppConfig
-- Template-Toolkit depends on Test-LeakTrace