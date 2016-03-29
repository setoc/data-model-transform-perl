# Controller
package MojoApp::Controller::Record;
use Mojo::Base 'Mojolicious::Controller';

# Action
sub read {
    
    my $self = shift;
    
    # Get message from stash
    my $table = $self->stash('table');
    my $id = $self->stash('id');
}

1;