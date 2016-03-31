# Controller
package MojoApp::Controller::Table;
use Mojo::Base 'Mojolicious::Controller';

use FindBin::libs;
use Database::Model;
use Data::Dumper;
my $root_dir = "c:/projects/model.perl";
my $mdl = Database::Model->new({'schema_file'=>"$root_dir/cfg/model_schema.xml",data_directory=>"$root_dir/data"});

# Action
sub read {
    my $self = shift;
    # Get message from stash
    my $table = $self->stash('table');
    $mdl->attach_userdb({user=>1});
    my $results = $mdl->select({user=>1,table=>$table});
    my @column_names = keys %{$results->[0]};
    #my $column_names = $mdl->{schema}->get_column_names($table);
    $self->stash('mydata'=>$results);
    $self->stash('column_names'=>\@column_names);
    $self->stash('counter'=>0);
    $self->render;
}

1;