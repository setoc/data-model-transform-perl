#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use Log::Log4perl qw(get_logger :levels);
use Model;
use Data::Dumper;


Log::Log4perl::init('log4perl.conf');
my $logger = Log::Log4perl->get_logger('main');
$logger->error("No drink defined");
$logger->debug("stuff: ",sub{"debug output from sub"});
my $params = {'schema_file'=>'model_schema.xml'};
my $mdl = Model->new($params);

my $db_user_file = $mdl->create_database('user',1,1);
#$dbix = $mdl->attach_userdb(1);

my $ug = Data::UUID->new;

my $start_run = time();
print "Start: $start_run\n";

$mdl->attach_userdb(1);
# USING A TRANSACTION IMPROVED PERFORMANCE FOR THE THOUSANDS OF INSERTS FROM 450 SECONDS TO 6 SECONDS
#$mdl->txn(\&create_data);
#$mdl->txn(\&load_data);
#$mdl->txn(\&delete_data);

#$mdl->txn(\&create_dataset);

$mdl->txn(\&load_dataset);

#print Dumper($dbix->schema);

my $end_run = time();
print "End: $end_run\n";
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";

sub create_dataset {
    $mdl->create_dataset(1,"test dataset");
}

sub load_dataset {
    $mdl->load_dataset(1,1);
}

sub load_data {
    my $list = $mdl->get_changeset_list();
    foreach my $item (@{$list}){
        $mdl->apply_changeset(1,$item->{id});
    }
}
sub delete_data {
    my $cs = $mdl->create_changeset('delete test',1);
    $mdl->delete(1,$cs,'DEVTYP',{record_id=>'D3F84653-6D3E-1014-A4D6-96D08D238A9C'});
}

sub create_data {
    my $cs = $mdl->create_changeset('create test',1);
    create_ref_tables($cs);
    create_station($cs,'ZAB');
}
sub create_ref_tables {
    my $cs = shift;
    for(my $i=0;$i<10; ++$i){
        my $rid = $ug->create_str();
        $mdl->insert(1,$cs,'PNTNAM',{'record_id'=>$rid,'ID'=>"PNT$i", 'DESCRIPTION'=>"Point $i"});
    }
}
sub create_station {
    my $cs = shift;
    my $id = shift;
    my $rid = $ug->create_str();
    $mdl->insert(1,$cs,'Substation',{'record_id'=>$rid,'ID'=>$id});
    for(my $i=0;$i<10; ++$i){
        create_devtyp($cs,"Devtyp$i", $rid);
    }
}
sub create_devtyp {
    my $cs = shift;
    my $id = shift;
    my $parent = shift;
    my $rid = $ug->create_str();
    $mdl->insert(1,$cs,'DEVTYP',{'record_id'=>$rid,'ID'=>$id,Substation=>$parent});
    for(my $i=0;$i<10; ++$i){
        create_device($cs, "Device$i", $rid);
    }
}
sub create_device {
    my $cs = shift;
    my $id = shift;
    my $parent = shift;
    my $rid = $ug->create_str();
    $mdl->insert(1,$cs,'DEVICE',{'record_id'=>$rid,'ID'=>$id,Devtyp=>$parent});
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
        my $pntnam = $mdl->select(1,'PNTNAM',{id=>$id});
        $pntnam{$id} = $pntnam->{record_id};
    }
    my $rid = $ug->create_str();
    $mdl->insert(1,$cs,'POINT',{'record_id'=>$rid,'ID'=>$pntnam{$id},Device=>$parent});
}

