# Controller
package MojoApp::Controller::Table;
use Mojo::Base 'Mojolicious::Controller';

#use Database::Model;
use Data::Dumper;
# Action
sub index {
    
    my $self = shift;
    
    # Get message from stash
    
    #my @results = $mdl->select({user=>1,table=>$table});
    #foreach my $row (@results){
    #    print Dumper($row);
    #}
}

1;