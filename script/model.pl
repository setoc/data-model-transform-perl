#!/usr/bin/perl
use 5.010;
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
my $root_dir = "$Bin/..";
use Log::Log4perl qw(get_logger :levels);
use Database::Model;
# UUID::Tiny may be slower than Data::UUID generating random UUIDs
#use Data::UUID;
use UUID::Tiny ':std';
use Data::Dumper;


Log::Log4perl::init("$root_dir/cfg/log4perl.conf");
my $logger = Log::Log4perl->get_logger('main');
$logger->error("No drink defined");
$logger->debug("stuff: ",sub{"debug output from sub"});

my $params = {'schema_file'=>"$root_dir/cfg/model_schema.xml",data_directory=>"$root_dir/data"};
my $mdl = Database::Model->new($params);

my $db_user_file = $mdl->create_database({db_type=>'user',user=>1,overwrite=>1});
#$dbix = $mdl->attach_userdb(1);

my $start_run = time();
print "Start: $start_run\n";

$mdl->attach_userdb({user=>1});
# USING A TRANSACTION IMPROVED PERFORMANCE FOR THE THOUSANDS OF INSERTS FROM 450 SECONDS TO 6 SECONDS
#$mdl->txn(\&create_data);

#$mdl->txn(\&load_data);

#$mdl->txn(\&delete_data);

#$mdl->txn(\&create_dataset);

$mdl->txn(\&load_dataset);

$mdl->txn(\&query_table);

#print Dumper($dbix->schema);

my $end_run = time();
print "End: $end_run\n";
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";

sub query_table {
    my @results = $mdl->select({user=>1,table=>'DEVTYP'});
    foreach my $row (@results){
        print Dumper($row);
    }
}

sub create_dataset {
    $mdl->create_dataset({user=>1,description=>"test dataset"});
}

sub load_dataset {
    $mdl->load_dataset({user=>1,dataset=>1});
}

sub load_data {
    my $list = $mdl->get_changeset_list();
    foreach my $item (@{$list}){
        $mdl->apply_changeset({user=>1,changeset=>$item->{id}});
    }
}
sub delete_data {
    my $cs = $mdl->create_changeset('delete test',1);
    $mdl->delete({user=>1,changeset=>$cs,table=>'DEVTYP',data=>{record_id=>'D3F84653-6D3E-1014-A4D6-96D08D238A9C'}});
}

sub create_data {
    my $cs = $mdl->create_changeset({description=>'create test',user=>1});
    create_ref_tables($cs);
    create_station($cs,'ZAB');
}
sub create_ref_tables {
    my $cs = shift;
    for(my $i=0;$i<10; ++$i){
        my $rid = create_uuid_as_string(UUID_RANDOM);
        $mdl->insert({user=>1,changeset=>$cs,table=>'PNTNAM',data=>{'record_id'=>$rid,'ID'=>"PNT$i", 'DESCRIPTION'=>"Point $i"}});
    }
}
sub create_station {
    my $cs = shift;
    my $id = shift;
    my $rid = create_uuid_as_string(UUID_RANDOM);
    $mdl->insert({user=>1,changeset=>$cs,table=>'Substation',data=>{'record_id'=>$rid,'ID'=>$id}});
    for(my $i=0;$i<10; ++$i){
        create_devtyp($cs,"Devtyp$i", $rid);
    }
}
sub create_devtyp {
    my $cs = shift;
    my $id = shift;
    my $parent = shift;
    my $rid = create_uuid_as_string(UUID_RANDOM);
    $mdl->insert({user=>1,changeset=>$cs,table=>'DEVTYP',data=>{'record_id'=>$rid,'ID'=>$id,Substation=>$parent}});
    for(my $i=0;$i<10; ++$i){
        create_device($cs, "Device$i", $rid);
    }
}
sub create_device {
    my $cs = shift;
    my $id = shift;
    my $parent = shift;
    my $rid = create_uuid_as_string(UUID_RANDOM);
    $mdl->insert({user=>1,changeset=>$cs,table=>'DEVICE',data=>{'record_id'=>$rid,'ID'=>$id,Devtyp=>$parent}});
    for(my $i=0;$i<10; ++$i){
        create_point($cs,"PNT$i", $rid);
    }
}
my %pntnam;
sub create_point {
    my $cs = shift;
    my $id = shift;
    my $parent = shift;
    if (not defined $pntnam{$id}){
        my $pntnam = $mdl->select({user=>1,table=>'PNTNAM',filter=>{id=>$id}});
        $pntnam{$id} = $pntnam->{record_id};
    }
    my $rid = create_uuid_as_string(UUID_RANDOM);
    $mdl->insert({user=>1,changeset=>$cs,table=>'POINT',data=>{'record_id'=>$rid,'Point_Name'=>$pntnam{$id},Device=>$parent}});
}

