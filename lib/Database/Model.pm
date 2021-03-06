#    Database::Model - Data modeling, data history, and data transformation library
#    Copyright (C) 2016  Sean O'Connell
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Database::Model;

=head1 NAME

Database::Model - Data modeling, data history, and data transformation library

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
use 5.010;
use strict;
use warnings;
use Log::Log4perl qw(get_logger :levels);
use XML::Parser;
use Data::Dumper;
use DBI;
use DBIx::Lite;
use UUID::Tiny ':std';
use FindBin::libs;
use Database::Model::Schema;

=head1 SYNOPSIS

Create and update a database schema and its records while preserving data history and then transform that data to other databases with different schemas or other formats.

    use Database::Model;

    my $mdl = Database::Model->new({'schema_file'=>"$root_dir/cfg/model_schema.xml",data_directory=>"$root_dir/data"});
    mdl->create_database({db_type=>'user',user=>1,overwrite=>1});
    $mdl->attach_userdb({user=>1});
    
    my $cs = $mdl->create_changeset({description=>'create test',user=>1});
    my $rid = create_uuid_as_string(UUID_RANDOM);
    $mdl->insert({user=>1,changeset=>$cs,table=>'Ingredient',data=>{'record_id'=>$rid,'ID'=>"Milk", 'DESCRIPTION'=>"White"}});
    
    my $ingredient = $mdl->select({user=>1,table=>'Ingredient',filter=>{id=>'Milk'}});
    
    $mdl->delete({user=>1,changeset=>$cs,table=>'Ingredient',data=>{record_id=>$rid}});
    
    mdl->create_database({db_type=>'user',user=>1,overwrite=>1});
    $mdl->apply_changeset({user=>1,changeset=>1});
    
    $mdl->create_dataset({user=>1,description=>"my first version of ingredients"});
    
    mdl->create_database({db_type=>'user',user=>1,overwrite=>1});
    $mdl->load_dataset({user=>1,dataset=>1});

=cut

my $logger = get_logger("Database::Model");
my $_dbix;

=head1 SUBROUTINES/METHODS

=head2 new

Parameter hash should include:

  schema_file=>'schema file name'
  data_directory=>'directory where databases are created'

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    foreach my $param (@_){
        if (ref $param eq 'HASH'){
            my %p = %{$param};
            foreach my $key (keys %p){
                $self->{$key} = $p{$key};
            }
        }
    }
    if(defined $self->{schema_file}){
        $self->{schema} = Database::Model::Schema->new({schema_file=>$self->{schema_file}});
        my $data_dir = (defined $self->{data_directory})? $self->{data_directory}:".";
        $self->{db_file} = $self->create_database({db_type=>'main',overwrite=>0,directory=>$data_dir});
        $self->init_dbix();
    }
    $self->{attached_dbs} = {};
}


=head2 create_database

Create a new database with the data schema from the schema file for the specified user. 
Parameter hash should include:

  user=>user-identifier
  db_type=>'main|user'
  overwrite=>0|1

=cut

sub create_database {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $dbtype = $params{db_type}; # user(data only) or main(meta and data)
    my $overwrite = $params{overwrite}; # boolean
    my $directory = $params{directory}; # where the database is stored
    my $schema_name = $self->{schema}->name(); 
    if(not defined $schema_name){
        $logger->error("no schema loaded. call new with schema_file specified");
        return undef;
    }
    $directory = (defined $directory)? $directory : (defined $self->{data_directory})? $self->{data_directory} : ".";
    if (not -d $directory){
        $logger->error("directory doesn't exist. create it first: $directory");
        return undef;
    }
    #create a file called schema_name - error if exists
    #iterate tables in schema
    # iterate columns in table
    #  build sql string for create table
    my $file_name = "";
    if(defined $dbtype and lc $dbtype eq 'main'){
        $file_name = $schema_name . "_main.sqlite3";
    }elsif(defined $dbtype and lc $dbtype eq 'user' and defined $user){
        $file_name = $schema_name . "_$user.sqlite3";
    }else{
        $logger->error("must specify dbtype and if dbtype==user then must specify user");
        return undef;
    }
    my $full_path = "$directory/$file_name";
    if(-f $full_path and not $overwrite){
        $logger->warn("database file already exists. not overwriting it: $full_path");
        return $full_path;
    }
    my $FH;
    unless(open($FH,'>', $full_path)){
        $logger->error("couldn't create database file: $full_path $!");
        return undef;
    }
    close($FH);
    my $driver = "SQLite";
    my $dsn = "DBI:$driver:dbname=$full_path";
    my $userid = "";
    my $password = "";
    my $dbh;
    unless($dbh = DBI->connect($dsn,$userid,$password,{RaiseError=>1})){
        $logger->error($DBI::errstr);
        return undef;
    }
    $logger->info("connected to database $full_path");
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        if($self->{schema}->table_type($table_name) eq 'meta' and lc $dbtype eq 'user'){
            next;
        }
        my $sql = "CREATE TABLE $table_name (";
        foreach my $column_name (@{$self->{schema}->get_column_names($table_name)}){
            my $data_type = $self->{schema}->column_data_type($table_name,$column_name);
            my $data_size = $self->{schema}->column_data_size($table_name,$column_name);
            my $primary_key = $self->{schema}->column_primary_key($table_name,$column_name);
            my $unique = $self->{schema}->column_unique($table_name,$column_name);
            my $not_null = $self->{schema}->column_not_null($table_name,$column_name);
            $sql .= $column_name;
            $sql .= " " . $data_type if defined $data_type;
            $sql .= "(" . $data_size . ")" if defined $data_size;
            $sql .= " PRIMARY KEY" if defined $primary_key
                    and (lc $dbtype ne 'main' or  $self->{schema}->table_type($table_name) eq 'meta');
            $sql .= " UNIQUE" if defined $unique;
            $sql .= " NOT NULL" if defined $not_null;
            $sql .= ",";
        }
        chop $sql;
        $sql .= ")";
        #print "\n$sql\n";
        my $rc = $dbh->do($sql);
        if($rc < 0){
            $logger->error($DBI::errstr);
        } else {
            $logger->info("created table $table_name");
        }
    }
    $dbh->disconnect();
    return $full_path;
}

sub init_dbix {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    if(not defined $self->{schema}->name()){
        $logger->error("no schema loaded. call get_schema first");
        return undef;
    }
    my $db_file = (defined $self->{db_file})? $self->{db_file}: shift;
    if(not defined $db_file){
        $logger->error("db filename is required");
        return undef;
    }
    $_dbix = DBIx::Lite->new;
    $_dbix->connect("DBI:SQLite:$db_file");
    
    #$_dbix->schema->table('SUBSTN')->pk('MRID');
    #$_dbix->schema->one_to_many('SUBSTN.MRID'=>'DEVTYP.SUBSTN_MRID','substn');
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        foreach my $column_name (@{$self->{schema}->get_column_names($table_name)}){
            # create primary key mapping
            my $primary_key = $self->{schema}->column_primary_key($table_name,$column_name);
            $_dbix->schema->table($table_name)->pk($column_name) if defined $primary_key;
            my $foreign_key = $self->{schema}->column_foreign_key($table_name,$column_name);
            if (defined $foreign_key){
                my $foreign_table = $self->{schema}->column_foreign_table($table_name,$column_name);
                if (defined $foreign_table){
                    my $foreign_column = $self->{schema}->column_foreign_column($table_name,$column_name);
                    if (defined $foreign_column){
                        my $parent_table = $foreign_table;
                        my $parent_column = $foreign_column;
                        # setup object mapping between related tables - parent->children[] and child->parent
                        $_dbix->schema->one_to_many($parent_table . "." . $parent_column => $table_name . "." . $column_name, $table_name);
                    }
                }
            }
        }
    }
    return $_dbix;
}

=head2 attach_userdb

Attach the previously created database for the specified user to the main database. 
Parameter hash should include:

  user=>user-identifier

=cut

sub attach_userdb {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $file_name = "";
    if(defined $user){
        $file_name = $self->{schema}->name() . "_$user.sqlite3";
    }else{
        $logger->error("must specify a valid user id");
    }
    my $directory = (defined $self->{data_directory})? $self->{data_directory} : ".";
    my $full_path = "$directory/$file_name";
    if(not -f $full_path){
        $logger->error("$full_path doesn't exist. create_database first.");
        return undef;
    }
    if(defined $self->{attached_dbs}->{$full_path}){
        $logger->warn("$full_path is already attached");
        return;
    }
    my $sch = "u$user";
    my $sql = "ATTACH DATABASE '$full_path' AS $sch";
    my $sth = $_dbix->dbh->prepare($sql);
    my $rc = $sth->execute();
    $logger->debug("attach_database rc=$rc");
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        next if($self->{schema}->table_type($table_name) eq 'meta' );
        foreach my $column_name (@{$self->{schema}->get_column_names($table_name)}){
            # create primary key mapping
            my $primary_key = $self->{schema}->column_primary_key($table_name,$column_name);
            $_dbix->schema->table("$sch.$table_name")->pk($column_name) if defined $primary_key;
            my $foreign_key = $self->{schema}->column_foreign_key($table_name,$column_name);
            if (defined $foreign_key){
                my $foreign_table = $self->{schema}->column_foreign_table($table_name,$column_name);
                if (defined $foreign_table){
                    my $foreign_column = $self->{schema}->column_foreign_column($table_name,$column_name);
                    if (defined $foreign_column){
                        my $parent_table = $foreign_table;
                        my $parent_column = $foreign_column;
                        # setup object mapping between related tables - parent->children[] and child->parent
                        $_dbix->schema->one_to_many("$sch.$parent_table" . "." . $parent_column => "$sch.$table_name" . "." . $column_name, "$sch.$table_name");
                    }
                }
            }
        }
    }
    $self->{attached_dbs}->{$full_path} = $sch;
    return $sch;
}

=head2 detach_userdb

Detach the previously attached database for the specified user from the main database. 
Parameter hash should include:

  user=>user-identifier

=cut

sub detach_userdb {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $file_name = "";
    if(defined $user){
        $file_name = $self->{schema}->name() . "_$user.sqlite3";
    }else{
        $logger->error("must specify a valid user id");
    }
    my $directory = (defined $self->{data_directory})? $self->{data_directory} : ".";
    my $full_path = "$directory/$file_name";
    if(not defined $self->{attached_dbs}->{$full_path}){
        $logger->warn("$full_path is not attached");
        return;
    }
    my $sql = "DETACH DATABASE u$user";
    my $sth = $_dbix->dbh->prepare($sql);
    my $rc = $sth->execute();
    delete $self->{attached_dbs}->{$full_path};
}

=head2 create_changeset

Create a changeset to start tracking the changes made to the database. 
Parameter hash should include:

  user=>user-identifier
  description=>'description for this changeset'

=cut

sub create_changeset {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $description = $params{description};
    # find max changeset id
    my $max = $self->_get_max("changeset","id");
    # insert new record
    my $id = $max + 1; #TODO: check this value is not greater than database column can hold or rolled over - not a problem for perl or sqlite I think
    my $changeset = $_dbix->table('changeset')->insert({id=>$id,description=>$description});
    # add record to changeset_user table
    $_dbix->table('changeset_user')->insert({changeset_id=>$id,user_id=>$user});
    return $id;
}

=head2 get_changeset_list

Retrieve a list of changesets. Each item is a hash {id,description,owner}.

=cut

sub get_changeset_list {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my @changeset_rs = $_dbix->table('changeset')->select('id','description','owner')->all();
    my @list;
    foreach my $item (@changeset_rs){
        my %cs;
        foreach my $column (keys %{$item->{data}}){
            $cs{$column} = $item->{data}->{$column};
        }
        push @list,\%cs;
    }
    return \@list;
}

sub _get_max {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $table_name = shift;
    my $column_name = shift;
    my $search = shift; # hash - {column=>'value'} or {column=>{'>'=>99}}
    my $max_rs;
    if(defined $search){
        $max_rs = $_dbix->table($table_name)->search($search)->select(\ "-MAX($column_name)");
    }else{
        $max_rs = $_dbix->table($table_name)->select(\ "-MAX($column_name)");
    }
    my ($sth, @bind) = $max_rs->select_sth;
    $sth->execute(@bind);
    my $max = +($sth->fetchrow_array)[0] || 0;
    return $max;
}

=head2 insert

Create a new row with the specified values. The record_id field is required and must be a UUID - it can be any version of UUID. If not using namespaces to create UUID, then version 4 is recommended. 
Parameter hash should include:

  user=>user-identifier
  changeset=>changeset-identifier
  table=>'table-name'
  data=>{record_id=>'UUID',field-name=>field-value,...}

=cut

sub insert {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $changeset = $params{changeset};
    my $table = $params{table};
    my $data = $params{data};
    if(not defined $user){
        $logger->error("user must be specified");
        return undef;
    }
    if(not defined $changeset){
        $logger->error("changeset must be specified");
        return undef;
    }
    if(not defined $table){
        $logger->error("table must be specified");
        return undef;
    }
    my $user_table = "u$user.$table";
    $data->{version_id} = create_uuid_as_string(UUID_RANDOM); # this is a new record, so it gets a new version id
    $_dbix->table($user_table)->insert($data);
    my $tx_id = $self->_get_max('change','transaction_id', {id_changeset=>$changeset}) + 1;
    my $change_id = $self->_get_max('change','id',{id_changeset=>$changeset}) + 1;
    # loop through data adding an Insert for each column in $data
    foreach my $column (keys %{$data}){
        next if lc $column eq 'record_id';
        $_dbix->table('change')->insert({id=>$change_id,id_changeset=>$changeset,transaction_id=>$tx_id,action=>'I',
                                         table_name=>$table,record_id=>$data->{record_id},column_name=>$column,
                                         new_value=>$data->{$column}});
        ++$change_id;
    }
}

=head2 select

If no filter is provided, return a list of all records.  If filter is a record_id, return that record.
Parameter hash should include:

  user=>user-identifier
  table=>'table-name'
  filter=>{record_id=>'UUID',field-name=>field-value,...}

=cut

sub select {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $table_name = $params{table};
    my $filter_hash = $params{filter};
    my $columns = $params{columns};
    if(not defined $user){
        $logger->error("user must be specified");
        return undef;
    }
    if(not defined $table_name){
        $logger->error("table must be specified");
        return undef;
    }
    if(not defined $columns){
        $columns = $self->{schema}->get_column_names($table_name);
    }
    # foreign key columns should display textual identifier instead of record_id
    # array of hash {$local_column=>{table=>$foreign_table,identifier=>$foreign_identifier},...}
    # OR part of the returned data [record_id,foreign_table.record_id,foreign_table.identifier]
    # select p.record_id,p.Device,p.Point_name,p.SITE,p.SITE2,S.ID,T.ID,N.ID
    # from point as p
    #   left join SITE as s on p.SITE=s.record_id
    #   left join SITE as t on p.SITE2=t.record_id
    #   left join PNTNAM as N on p.Point_name=N.record_id

    my $identifiers = $self->{schema}->get_foreign_identifiers($table_name,$columns);    
    my $user_table = "u$user.$table_name";
    if(defined $filter_hash){
        my $item;
        $item = $_dbix->table($user_table)->select(@{$columns})->find($filter_hash);
        my %result;
        foreach my $c (keys %{$item->{data}}){
            $result{$c} = $item->{data}->{$c};
        }
        return \%result;
    }else{
        my $counter = 1;
        my @foreign_columns;
        my @select_columns;
        foreach my $c (@{$columns}){push @select_columns,"t0.$c";}
        my $from_tables = " from $table_name as t0 ";
        foreach my $identifier (@{$identifiers}){
            my $foreign_table = $identifier->{foreign_table};
            my $local_column = $identifier->{local_column};
            my $foreign_id = $identifier->{foreign_id};
            $from_tables .= " left join u$user.$foreign_table as t$counter on t0.$local_column=t$counter.record_id ";
            push @foreign_columns, "$foreign_table.$foreign_id";
            push @select_columns,"t$counter.$foreign_id";
            ++$counter;
        };
        push @{$columns},@foreign_columns;
        my $sql = "select " . (join ',',@select_columns) . $from_tables;
        say $sql;
        my $sth = $_dbix->dbh->prepare($sql);
        my $rc = $sth->execute();
        
        my @results;
        while (my @items = $sth->fetchrow_array()) {
            my %hash;
            @hash{@{$columns}} = @items;
            push @results, \%hash;
        }
        return \@results;
    }
}

=head2 update

Update the specified record_id with the specified new information.  Don't need to include all fields for an update. Only the data that actually changed is updated.
Parameter hash should include:

  user=>user-identifier
  table=>'table-name'
  changeset=>changeset-identifier
  data=>{record_id=>'UUID',field-name=>field-value,...}

=cut

sub update {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $changeset = $params{changeset};
    my $table = $params{table};
    my $data = $params{data};
    if(not defined $user){
        $logger->error("user must be specified");
        return undef;
    }
    if(not defined $changeset){
        $logger->error("changeset must be specified");
        return undef;
    }
    if(not defined $table){
        $logger->error("table must be specified");
        return undef;
    }
    my $user_table = "u$user.$table";
    my $tx_id = $self->_get_max('change','transaction_id', {id_changeset=>$changeset}) + 1;
    my $change_id = $self->_get_max('change','id',{id_changeset=>$changeset}) + 1;
    my $old_data = $_dbix->table($user_table)->find({ record_id => $data->{record_id} });
    if (not defined $old_data){
        $logger->error("couldn't find record_id in database: ". $data->{record_id});
        return undef;
    }
    my $found_difference = 0;
    foreach my $column (keys %{$data}){
        if($data->{$column} ne $old_data->$column){
            #print "$column is different\n";
            $found_difference = 1;
            $_dbix->table('change')->insert({id=>$change_id,id_changeset=>$changeset,transaction_id=>$tx_id,action=>'U',
                                         table_name=>$table,record_id=>$data->{record_id},column_name=>$column,
                                         new_value=>$data->{$column}, old_value=>$old_data->$column});
            ++$change_id;
            $old_data->update({$column=>$data->{$column}});
        }
    }
    if($found_difference){
        my $vid = create_uuid_as_string(UUID_RANDOM); # this is an updated record, so it gets a new version id
        $_dbix->table('change')->insert({id=>$change_id,id_changeset=>$changeset,transaction_id=>$tx_id,action=>'U',
                                         table_name=>$table,record_id=>$data->{record_id},column_name=>'version_id',
                                         new_value=>$vid, old_value=>$old_data->version_id});
        $old_data->update({version_id=>$vid});
    }
}

=head2 delete

Delete the specified record and all child records in a one to many relationship. Also scrub all references to any of the deleted records.
Parameter hash should include:

  user=>user-identifier
  table=>'table-name'
  changeset=>changeset-identifier
  data=>{record_id=>'UUID'}

=cut

sub delete {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $changeset = $params{changeset};
    my $table = $params{table};
    my $data = $params{data};
    if(not defined $user){
        $logger->error("user must be specified");
        return undef;
    }
    if(not defined $changeset){
        $logger->error("changeset must be specified");
        return undef;
    }
    if(not defined $table){
        $logger->error("table must be specified");
        return undef;
    }
    my $user_table = "u$user.$table";
    my $tx_id = $self->_get_max('change','transaction_id', {id_changeset=>$changeset}) + 1;
    my $change_id = $self->_get_max('change','id',{id_changeset=>$changeset}) + 1;

    $self->_delete_recurse($user,$changeset,$table,$data,$tx_id,$change_id);
}

sub _delete_recurse {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $user = shift;
    my $changeset = shift;
    my $table = shift;
    my $data = shift;
    my $tx_id = shift;
    my $change_id = shift;
    my $sch = "u$user";
    my $user_table = "u$user.$table";
    my $old_data = $_dbix->table($user_table)->find({ record_id => $data->{record_id} });
    if (not defined $old_data){
        $logger->error("couldn't find record_id in database: ". $data->{record_id});
        return undef;
    }
    if(defined $self->{schema}->{associations}->{$table}){
        foreach my $item (@{$self->{schema}->{associations}->{$table}}){
            my $rtab = "$sch." . $item->{table};
            my $rcol = $item->{column};
            if($item->{relationship} eq 'one_to_many'){
                my @refs = $_dbix->table($rtab)->search({$rcol=>$data->{record_id}})->get_column('record_id');
                #parent-child - delete all children - need list of record_id
                foreach my $child (@refs){
                    $change_id = $self->_delete_recurse($user,$changeset,$item->{table}
                                           ,{record_id=>$child}
                                           ,$tx_id,$change_id);
                }
            }elsif($item->{relationship} eq 'one_to_one'){
                my @refs = $_dbix->table($rtab)->search({$rcol=>$data->{record_id}})->all();
                #indirect - set column to null
                foreach my $ref (@refs){
                    $_dbix->table('change')->insert({id=>$change_id,id_changeset=>$changeset,transaction_id=>$tx_id,action=>'U',
                                                     table_name=>$item->{table},record_id=>$ref->record_id,column_name=>$rcol,
                                                     old_value=>$ref->$rcol,new_value=>undef});
                    ++$change_id;
                    $ref->update({$rcol=>undef});
                }
            }
        }
    }
    foreach my $column (keys %{$old_data->{data}}){
        # don't need to track changes for record_id because it is included with each entry
        if($column ne 'record_id'){
            $_dbix->table('change')->insert({id=>$change_id,id_changeset=>$changeset,transaction_id=>$tx_id,action=>'D',
                                         table_name=>$table,record_id=>$data->{record_id},column_name=>$column,
                                         old_value=>$old_data->{data}->{$column}});
            ++$change_id;
        }
    }
    $old_data->delete();
    return $change_id;
}

=head2 apply_changeset

Load all the changes included in the specified changeset into the user's database.
Parameter hash should include:

  user=>user-identifier
  changeset=>changeset-identifier

=cut

sub apply_changeset {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $changeset = $params{changeset};
    my $sch = "u$user";
    my @changes = $_dbix
        ->table('change')
        ->search({id_changeset=>$changeset})
        ->order_by('id')
        ->all;
    my %current_record;
    $self->_init_record(\%current_record);
    foreach my $c (@changes){
        my $table = "$sch." . $c->table_name;
        my $column = $c->column_name;
        my $record_id = $c->record_id;
        # keep updating record via loop
        # - especially if action is update for the same record_id (may be different transaction_id)
        if($current_record{record_id} ne $record_id or $current_record{action} ne $c->action){
            $self->_commit_record(\%current_record);
            $self->_init_record(\%current_record);
        }
        $current_record{record_id} = $c->record_id;
        $current_record{action} = $c->action;
        $current_record{table} = $table;
        $current_record{columns}{$column} = $c->new_value if $c->action eq 'I' or $c->action eq 'U';
    }
    if($current_record{record_id} ne ""){
        $self->_commit_record(\%current_record);
        $self->_init_record(\%current_record);
    }
    $_dbix->table('changeset_user')->insert({changeset_id=>$changeset,user_id=>$user});
}
sub _init_record {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $rec = shift;
    $rec->{record_id} = "";
    $rec->{action} = "";
    $rec->{table} = "";
    $rec->{columns} = {};
}
sub _commit_record {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $rec = shift;
    if($rec->{action} eq 'I'){
        $rec->{columns}{record_id} = $rec->{record_id};
        $_dbix->table($rec->{table})->insert($rec->{columns});
    }elsif($rec->{action} eq 'U'){
        $_dbix->table($rec->{table})->search({record_id=>$rec->{record_id}})->update($rec->{columns});
    }elsif($rec->{action} eq 'D'){
        $_dbix->table($rec->{table})->delete({record_id=>$rec->{record_id}});
    }
}

=head2 txn

Start a transaction for the specified code-ref. This speeds up database operations immensely if performing multiple operations.

=cut

sub txn {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $coderef = shift;
    $_dbix->txn($coderef);
}

=head2 create_dataset

Create a snapshot of the user's database.
Parameter hash should include:

  user=>user-identifier
  description=>'why is this snapshot note-worthy'

=cut

sub create_dataset {
    # insert dataset_info record
    # select user table data where version_id not in main table data
    # insert into main table selected data
    # insert into dataset (table_name,record_id,version_id,dataset_id) values ('table_name',(select record_id,version_id,dataset_id from user table))
    # insert into dataset_changeset {user's changesets}
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $description = $params{description};
    my $now = localtime;
    my $ds_id = $self->_get_max("dataset_info","dataset_id") + 1;
    $_dbix->table('dataset_info')->insert({dataset_id=>$ds_id,description=>$description,date_created=>$now,created_by=>$user});
    my $sch = "u$user";
    my $sql = "";
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        if($self->{schema}->table_type($table_name) eq 'data'){
            my $cols = $self->{schema}->get_column_names($table_name);
            my $cols_str = join ',',@{$cols};
            $sql = "insert into $table_name ($cols_str) select $cols_str from $sch.$table_name where version_id not in (select version_id from $table_name)";
            my $rc = $_dbix->dbh->do($sql);
            $sql = "insert into dataset (version_id,record_id,table_name,dataset_id) select version_id,record_id,'$table_name','$ds_id' from $sch.$table_name";
            $rc = $_dbix->dbh->do($sql);
        }
    }
    $sql = "insert into dataset_changeset (dataset_id,changeset_id) select '$ds_id',changeset_id from changeset_user where user_id='$user'";
    my $rc = $_dbix->dbh->do($sql);
    return $ds_id;
}

=head2 load_dataset

Load the data from the specified dataset into the user's database.
Parameter hash should include:

  user=>user-identifier
  dataset=>dataset-identifier

=cut

sub load_dataset {
    # select version_id from dataset where dataset_id='x' and table_name='x'
    # insert into user.table_name (select * from table_name where version_id = version_id)
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $ds_id = $params{dataset};
    my $sch = "u$user";
    my $sql = "";
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        if($self->{schema}->table_type($table_name) eq 'data'){
            my $cols = $self->{schema}->get_column_names($table_name);
            my $cols_str = join ',',@{$cols};
            $sql = "insert into $sch.$table_name ($cols_str) select $cols_str from $table_name where version_id in (select version_id from dataset where dataset_id=$ds_id and table_name like '$table_name')";
            my $rc = $_dbix->dbh->do($sql);
            print "\n$sql\n";
        }
    }
}

=head2 reset_database

Clear all the data from the specified user's database. 
Parameter hash should include:

  user=>user-identifier

=cut

sub reset_database {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $params = shift;
    my %params = %{$params};
    my $user = $params{user};
    my $sch = "u$user";
    my $sql = "";
    foreach my $table_name (@{$self->{schema}->get_table_names}){
        if($self->{schema}->table_type($table_name) eq 'data'){
            $sql = "delete from $sch.$table_name";
            my $rc = $_dbix->dbh->do($sql);
        }
    }
}


=head1 AUTHOR

Sean O'Connell, C<< <oconnellseant at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-foo-bar at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Foo-Bar>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Database::Model


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Foo-Bar>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Foo-Bar>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Foo-Bar>

=item * Search CPAN

L<http://search.cpan.org/dist/Foo-Bar/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

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


=cut

1;
