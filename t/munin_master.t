use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Munin::Master');

$t->get_ok('/')
    ->status_is(200)
    ->json_has('/nav_categories')
    ->json_has('/nav_categories/0/NAME')
    ->json_has('/nav_categories/0/R_PATH')
    ->json_has('/nav_categories/0/URLday')
    ->json_has('/nav_categories/0/URLmonth')
    ->json_has('/nav_categories/0/URLweek')
    ->json_has('/nav_categories/0/URLyear')
    ->json_has('/nav_groups')
    ->json_has('/nav_groups/0/NAME')
    ->json_has('/nav_groups/0/R_PATH')
    ->json_has('/nav_groups/0/URL')
    ->json_has('/nav_problems')
    ->json_has('/nav_problems/0/NCRITICALS')
    ->json_has('/nav_problems/0/NUNKNOWNS')
    ->json_has('/nav_problems/0/NWARNINGS');

$t->get_ok('/node')
    ->status_is(200)
    ->content_like(qr/node page/i);

$t->get_ok('/service')
    ->status_is(200)
    ->content_like(qr/service page/i);

$t->get_ok('/problems')
    ->status_is(200)
    ->content_like(qr/problems page/i);

$t->get_ok('/comparison')
    ->status_is(200)
    ->content_like(qr/comparison page/i);

$t->get_ok('/group')
    ->status_is(200)
    ->content_like(qr/group page/i);

$t->get_ok('/graph/test')
    ->status_is(200)
    ->content_like(qr/test ok/i);

$t->get_ok('/img/logo.png')
    ->status_is(200)
    ->content_type_is('image/png');

done_testing();
