use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Munin::Master');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

$t->get_ok('/html/test')
    ->status_is(200)
    ->content_like(qr/test ok/i);

$t->get_ok('/graph/test')
    ->status_is(200)
    ->content_like(qr/test ok/i);

done_testing();
