use strict;
use warnings;

use Test::More;
use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.003001 qw( dztest );
use Path::Tiny;
use JSON::MaybeXS;

# ABSTRACT: Basic test

use constant HATEFULMODNAME    => 'Please::Do::Not::Invent::This::Module::Or::Install::It';
use constant HATEFULMODNAMETWO => 'Also::Please::Do::Not::Invent::This::Module::Or::Install::It';

my $ini = simple_ini(
  ['GatherDir'],
  [
    'Prereqs',
    'Before' => {
      'Dist::Zilla' => 0,
      -phase        => 'runtime',
      -type         => 'requires',
    }
  ],
  [
    'MetaData::BuiltWith' => {
      include => [HATEFULMODNAME],
      exclude => [ 'Moose', HATEFULMODNAMETWO ],
    }
  ],
  [
    'Prereqs',
    'After' => {
      Moose  => 0,
      -phase => 'runtime',
      -type  => 'requires',
    }
  ],
  [ 'MetaJSON' => {} ],
);
my $test = dztest();
$test->add_file( 'dist.ini', $ini );
$test->build_ok;
note explain $test->builder->log_events;
## Note: this is required because MD:BW wraps the META.json
## file fromCode object to inject during write.
## I'm not sure I like that. But either way, it hides from distmeta!
my $json = $test->test_has_built_file('META.json');

my $content = JSON::MaybeXS->new->decode( $json->slurp_raw );

ok( exists $content->{x_BuiltWith}, 'x_BuiltWith is there' );

my $xb = $content->{x_BuiltWith};

note explain $xb;

subtest 'platform' => sub {
  ok( exists $xb->{platform}, 'platform key exists' );
  ok( length $xb->{platform}, 'platform has length' );
};
subtest 'modules' => sub {
  return unless ok( exists $xb->{modules}, 'modules key exists' );
  for my $module (qw( Dist::Zilla )) {
    ok( exists $xb->{modules}->{$module}, $module . ' is there' );
    like( $xb->{modules}->{$module}, qr/\d/, $module . ' has a number' );
  }
};
subtest 'perl' => sub {
  return unless ok( exists $xb->{perl}, 'perl key exists' );
  for my $field (qw( original qv version )) {
    ok( exists $xb->{perl}->{$field}, $field . ' is there' );
  }
};

ok( exists $xb->{failures}, 'Failures reported' );

ok( exists $xb->{modules}->{'Dist::Zilla'},      'Dist::Zilla still reported' );
ok( !exists $xb->{modules}->{'Moose'},           'Moose excluded' );
ok( !exists $xb->{modules}->{ +HATEFULMODNAME }, 'Bad mod was not found' );
ok( exists $xb->{failures}->{ +HATEFULMODNAME }, 'Bad mod gave failure' );

done_testing;

