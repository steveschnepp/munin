package Munin::Master::Update::Tests;
use base qw(Test::Class);
use Test::More;
use Test::MockModule;

use File::Temp qw(tempdir);

use Munin::Master::Update;
use Munin::Master::Config;
use Munin::Common::Logger;

use Carp;
$Carp::Verbose = 1;

sub setup : Test(setup) {
    my $self = shift;

    $self->{update} = Munin::Master::Update->new();

    my %log;
    $log{output} = 'screen';
    $log{level}  = 'debug';

    Munin::Common::Logger::configure(%log);

    $self->{config} = Munin::Master::Config->instance()->{config};
    $self->{config}->parse_config_from_file();

}

sub class : Test(1) {
    my $update = shift->{update};
    isa_ok( $update, 'Munin::Master::Update' );
}

sub method__run : Test(3) {
    my $self   = shift;
    my $update = $self->{update};

    can_ok( $update, 'run' );

    return 'Set TEST_HEAVY to use these tests'
      . ' and provide a munin node on localhost:4949'
      unless $ENV{TEST_HEAVY};

    my $mock_rrds = Test::MockModule->new("RRDs");
    $mock_rrds->mock('create',  sub(@) { });
    $mock_rrds->mock('error',  sub { });

    $mock_node = Test::MockModule->new("Munin::Master::Node");
    $mock_node->mock('_do_connect', undef );
    $mock_node->mock('_do_close', undef );
    $mock_node->mock('negotiate_capabilities', sub { return ( "multigraph", ) });
    $mock_node->mock('negotiate_capabilities', sub { return ( "multigraph", ) });
    $mock_node->mock('list_plugins', sub { return ("a", "b", "c", ) });
    $mock_node->mock('fetch_service_config', sub {
		    my ($self, $service, $uw_handle_config) = @_;
		    DEBUG "[DEBUG] Mocking service configuration for '$service'";
	    });
    $mock_node->mock('fetch_service_data', sub { });

    my $config = Munin::Master::Config->instance()->{config};
    $config->{dbdir}  = tempdir( CLEANUP => 1 );
    $config->{rundir} = tempdir( CLEANUP => 1 );

    ok( eval{$update->get_dbh()} );
    ok( eval{$update->run} );
}

1;
