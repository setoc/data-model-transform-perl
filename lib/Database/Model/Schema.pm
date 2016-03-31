#    Database::Model:Schema - Data modeling, data history, and data transformation library
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

package Database::Model::Schema;

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

=head1 SYNOPSIS

Parse a database schema from xml. Case in-sensitive retrieval of data from hash.

    use Database::Model::Schema;

    my $schema = Database::Model::Schema->new({'schema_file'=>"$root_dir/cfg/model_schema.xml"});
    my @tables = $schema->get_tables();
    my @columns = $schema->get_columns($table_name);

=cut

my $logger = get_logger("Database::Model::Schema");
my %_state; # for parsing xml
my %_schema; # for storing parsed xml

=head1 SUBROUTINES/METHODS

=head2 new

Parameter hash should include:

  schema_file=>'schema/file/path/name.xml'

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
        $self->{schema} = $self->_load_schema();
        $self->_get_associations();
        $self->_build_graph();
    }
}

sub name {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    return $self->{schema}{name};
}

sub associations {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    return $self->{associations};
}

=head2 get_column_names

Pass in the table name to retrieve the column names as specified in the schema file.

=cut

sub get_column_names {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    $logger->debug(Dumper($self->{schema}{tables}));
    my @columns;
    foreach my $c (keys %{$self->{schema}{tables}{$table_name}{columns}}){
        push @columns,$c;
    }
    $logger->debug("table [$table_name] columns: " . Dumper(\@columns));
    return \@columns;
}

=head2 get_table_names

Retrieve the table names as specified in the schema file.

=cut

sub get_table_names {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my @tables;
    foreach my $t (keys %{$self->{schema}{tables}}){
        push @tables,$t;
    }
    return \@tables;
}

sub table_info {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    return $self->{schema}{tables}{$table_name};
}

sub column_info {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name};
}

sub table_type {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    return $self->{schema}{tables}{$table_name}{type};
}

sub column_data_type {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{data_type};
}

sub column_data_size {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{data_size};
}

sub column_unique {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{unique};
}

sub column_not_null {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{not_null};
}

sub column_primary_key {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{primary_key};
}

sub column_foreign_key {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{foreign_key};
}

sub column_foreign_table {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{foreign_table};
}

sub column_foreign_column {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{foreign_column};
}

sub column_relationship {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_name = shift;
    my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
    return $self->{schema}{tables}{$table_name}{columns}{$column_name}{relationship};
}

sub get_foreign_identifiers {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $unsafe_table_name = shift;
    my $table_name = $self->{safe_tables}{lc $unsafe_table_name}{name};
    my $unsafe_column_names = shift;
    my @results;
    foreach my $unsafe_column_name (@{$unsafe_column_names}){
        my $column_name = $self->{safe_tables}{lc $unsafe_table_name}{columns}{lc $unsafe_column_name};
        next if $column_name eq 'version_id';
        next if $column_name eq 'record_id';
        if(defined $self->{schema}{tables}{$table_name}{columns}{$column_name}{foreign_key}){
            my $foreign_table = $self->{schema}{tables}{$table_name}{columns}{$column_name}{foreign_table};
            my $foreign_id = $self->{identifiers}{$foreign_table};
            # this is a problem if there is more than one column that references the same table
            push @results,{'foreign_table'=>$foreign_table,'local_column'=>$column_name,'foreign_id'=>$foreign_id};
        }
    }
    return \@results;
}

sub _build_graph {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    foreach my $table (keys %{$self->{schema}{tables}}){
        $self->{safe_tables}{lc $table}{name} = $table;
        foreach my $column (keys %{$self->{schema}{tables}{$table}{columns}}){
            $self->{safe_tables}{lc $table}{columns}{lc $column} = $column;
            if(defined $self->{schema}{tables}{$table}{columns}{$column}{identifier}){
                $self->{identifiers}{$table}=$column;
            }
        }
    }
}

sub _load_schema {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    my $data = shift;
    my $p = XML::Parser->new(Handlers => {
        Start => \&_handle_start,
        End => \&_handle_end,
    });
    $_state{"state"} = undef;
    if(not defined $data){
        if(defined $self->{schema_file}){
            $logger->debug("Loading schema: " . $self->{schema_file});
            $p->parsefile($self->{schema_file});
        }else{
            $logger->error("no schema file defined and no xml provided");
            return undef;
        }
    }else{
        $p->parse($data);
    }
    #$logger->debug(Dumper(\%_schema));
    return \%_schema;
}

sub _get_associations {
    my $self = shift;
    unless (ref $self) {
        $logger->error("should call with an object, not a class");
        return undef;
    }
    # loop through tables building hash of foreign-table = ['table.column.relationship',...]
    # this data-structure allows finding all the columns that reference another table's column
    foreach my $table (keys %{$self->{schema}{tables}}){
        foreach my $column (keys %{$self->{schema}{tables}{$table}{columns}}){
            next if $column eq 'version_id';
            if (defined $self->{schema}{tables}{$table}{columns}{$column}{foreign_key}){
                my $ft = $self->{schema}{tables}{$table}{columns}{$column}{foreign_table};
                my $relationship = $self->{schema}{tables}{$table}{columns}{$column}{relationship};
                my %item;
                $item{table} = $table;
                $item{column} = $column;
                $item{relationship} = $relationship;
                push @{$self->{associations}->{$ft}},\%item;
            }
        }
    }
}

# not sure if using a global %_schema and %_state here where cause problems in the future
sub _handle_start {
    my ($expat,$el,%atts) = @_;
    if($el eq 'schema' and not defined $_state{'state'}){
        $_state{"state"} = "inside_schema";
        $_schema{'tables'}={};
        foreach my $key (keys %atts){
            $_schema{lc $key} = $atts{$key};
        }
    }elsif($el eq 'table' and $_state{"state"} eq "inside_schema"){
        $_state{'state'} = "inside_table";
        $_schema{'tables'}{$atts{'name'}}{'columns'}={};
        $_state{'current_table'} = $atts{'name'};
        foreach my $key (keys %atts){
            $_schema{'tables'}{$atts{'name'}}{lc $key} = $atts{$key};
        }
    }elsif($el eq 'column' and $_state{"state"} eq "inside_table"){
        $_state{'state'} = "inside_column";
        $_schema{'tables'}{$_state{'current_table'}}{'columns'}{$atts{'name'}}={};
        $_state{'current_column'} = $atts{'name'};
        foreach my $key (keys %atts){
            $_schema{'tables'}{$_state{'current_table'}}{'columns'}{$atts{'name'}}{lc $key} = $atts{$key};
        }
    }
}

sub _handle_end {
    my ($expat,$el) = @_;
    if($el eq 'schema'){
        $_state{'state'} = undef;
    }elsif($el eq 'table'){
        $_state{'state'} = "inside_schema";
        $_state{'current_table'} = undef;
    }elsif($el eq 'column'){
        $_state{'state'} = "inside_table";
        $_state{'current_column'} = undef;
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
