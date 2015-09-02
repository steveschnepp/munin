package Munin::Master;
use Mojo::Base 'Mojolicious';

use DBI;
use DBD::SQLite;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

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

    # Switch to installable "public" directory
    $self->static->paths->[0] = $self->home->rel_dir('web/static');

    $self->helper(
        'db' => sub {
            my $dbfile = $self->home->rel_dir('t/fixtures/datafile.sqlite');
            state $dbh = DBI->connect(
                "dbi:SQLite:$dbfile",
                undef, undef,
                {
                    sqlite_open_flags => DBD::SQLite::OPEN_READONLY,
                }
            );
        }
    );

}

1;
