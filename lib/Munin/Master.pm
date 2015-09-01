package Munin::Master;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');

  $r->get('/graph/test/')->to('graph#test');

  $r->get('/html/test/')->to('HTML#test');

  # Switch to installable "public" directory
  $self->static->paths->[0] = $self->home->rel_dir('web/static');

}

1;
