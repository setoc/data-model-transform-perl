# Model

Multi-user Data modeling and transformation based on perl and sql database. 

Describe a data model schema with XML and how to transform that data to other databases.
The XML schema file is used to generate a SQL database and helps the code perform inserts, updates, and deletes on data in the SQL database.
When a data model is complete, create a snapshot of it for historical use, and export the data to other databases.

Multiple users can work in parallel, creating changes to the data model, and all changes can be merged into a single data model.

## INSTALLATION

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make install

### PRE-REQUISITES

( based on ActiveState Perl 5.22.1 )
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
- Mojolicious
- Module-Starter ( not used in the code but used to create the project skeleton )
-- Module-Install-AuthorTests
-- Path-Class
-- Module-Install
-- Win32-UTCFileTime
-- Module-ScanDeps
-- File-Remove
-- YAML-Tiny
- FindBin-libs

## SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Model

## WORKING WITH SOURCE

```
git clone https://github.com/setoc/data-model-transform-perl.git model.perl
cd model.perl
```
Use a sqlite shell to examine the databases.

## LICENSE AND COPYRIGHT

    Model.pm - Data modeling, data history, and data transformation library
    Copyright (C) 2016  Sean O'Connell

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

