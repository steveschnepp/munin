package Munin::Master;
use Mojo::Base 'Mojolicious';

use DBI;
use DBD::SQLite;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    $self->_setup_config;
    $self->_setup_static;
    $self->_setup_routes;
    $self->_setup_helpers;
}

sub _setup_config {
    my $self   = shift;
    my $config = $self->plugin('Config');
}

sub _setup_static {
    my $self = shift;
    $self->static->paths->[0] = $self->home->rel_dir('web/static');
}

sub _setup_routes {
    my $self = shift;

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('HTML#welcome');
    $r->get('/node')->to('HTML#node');
    $r->get('/service')->to('HTML#service');
    $r->get('/comparison')->to('HTML#comparison');
    $r->get('/group')->to('HTML#group');
    $r->get('/problems')->to('HTML#problems');

    # Simple test routes
    $r->get('/graph/test/')->to('graph#test');
}

sub _setup_helpers {
    my $self = shift;

    $self->helper(
        'db' => sub {
            my $dbfile = $self->config->{dbfile};
            state $dbh = DBI->connect( "dbi:SQLite:$dbfile", undef, undef,
                { sqlite_open_flags => DBD::SQLite::OPEN_READONLY, } );
        }
    );
}

1;
