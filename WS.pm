package WS;
use 5.010;
use strict;
use warnings;
use HTTP::Daemon;
use HTTP::Status;
use Template;
use Model;
use Data::Dumper;

my $d;
my $mdl;

sub init {
    my $params = {'schema_file'=>'model_schema.xml'};
    $mdl = Model->new($params);
    $mdl->attach_userdb(1);
}

sub run {
    $d = HTTP::Daemon->new(
           LocalAddr => 'localhost',
           LocalPort => 8080,
    );
    print "Please contact me at: <URL:", $d->url, ">\n";
    while (my $c = $d->accept) {
	while (my $r = $c->get_request) {
	    if ($r->method eq 'GET' and $r->uri->path eq "/hello") {
		my $rs = new HTTP::Response(RC_OK);
		#$rs->content( \&hello );
		
                my $text = get_table_template('POINT');
		$rs->content($text);
		$c->send_response($rs);
	    }
	    else {
		$c->send_error(RC_FORBIDDEN)
	    }
	}
	$c->close;
	undef($c);
    }
}

# use code reference in HTTP::Response->content(\&mysub)
# sub will be called until it returns undef
my $state = 0;
sub hello {
    $state++;
    return $state if $state < 5;
    return undef;
}

sub get_table_template {
    my $table_name = shift;
    my $file_name = 'table.tt';
    my $columns = $mdl->get_column_names($table_name);
    my $vars = {
        'table_name'=>$table_name,
        'columns'=>$columns, # array ref
        'rows'=>$mdl->select({user=>1,table=>$table_name,columns=>$columns}) # array ref of hashes
    };
    my $template = Template->new();
    my $result='';
    $template->process($file_name,$vars,\$result);
    return $result;
}

1;
