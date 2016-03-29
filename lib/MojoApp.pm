package MojoApp;

use strict;
use warnings;

use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;
    
    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
  
    # router
    my $r = $self->routes;
  
    $r->get('/')->to(controller=>'home',action=>'index');
    
    # controller one of record,table,hierarchy.
    # use POST,GET,PUT,DELETE http methods to do create, read, update, or delete records
    $r->get('/:controller/:table/:id' => [controller=>['record','table','hierarchy']])->to(action=>'read', id=>0);
    #$r->post('/:controller/:table/:id')->to('record#create', table=>'dataset_info');
    #$r->put('/:controller/:table/:id')->to('record#update', table=>'dataset_info');
    #$r->delete('/:controller/:table/:id')->to('record#delete', table=>'dataset_info');
    
    # default route for all requests - route used if no previous route matches request
    #$r->route('/:controller/:action/:id')->to('foo#welcome', id => 1);
    
    # NOTE: reserved words in stash:
    # action, app, cb, controller, data, extends, format, handler, inline, json, layout, namespace, path, status, template, text, variant
    # NOTE: The controller value gets converted from snake_case to CamelCase.  During camelization - characters get replaced with ::
    # NOTE: use the cb stash key to specify a callback sub instead of a controller to handle the request
    # NOTE: All uppercase methods as well as those starting with an underscore are automatically hidden from the router and you can use "hide" in Mojolicious::Routes to add additional ones
}

1;
