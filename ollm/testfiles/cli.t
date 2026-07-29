use v5.30;
use strict;
use warnings;

use Test::More;
use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::CLI;

my $plan = OLLM::CLI->parse(qw(build presentation --language=en --source=talk.tex --dry-run));
is $plan->{action}, 'build', 'explicit build action';
is $plan->{target}, 'slides', 'presentation alias';
is $plan->{language}, 'en', 'new language option';
is $plan->{source}, 'talk.tex', 'explicit source';
ok $plan->{dry_run}, 'dry-run enabled';

$plan = OLLM::CLI->parse(qw(+lang=de +article -silent main.tex));
is $plan->{target}, 'script', 'legacy target alias';
is $plan->{language}, 'de', 'legacy language option';
is_deeply $plan->{latexmk_args}, ['-silent'], 'unknown minus option for latexmk';
is $plan->{source}, 'main.tex', 'legacy source operand';

$plan = OLLM::CLI->parse(qw(debug slides));
is $plan->{debug}, 'tex', 'bare debug compatibility default';

$plan = OLLM::CLI->parse(qw(build --target=keynote --language=en));
is $plan->{target}, 'keynote',
  'explicit target option accepts a registered extension name';
ok $plan->{target_explicit}, 'extended target selection is marked explicit';

$plan = OLLM::CLI->parse(qw(build --target presentation));
is $plan->{target}, 'slides',
  'explicit target option normalizes compatibility aliases';

eval { OLLM::CLI->parse(qw(build --target=not/a/target)) };
like $@, qr/invalid target/, 'non-portable explicit target is rejected';

$plan = OLLM::CLI->parse(qw(--debug slides));
is $plan->{debug}, 'tex', 'valueless new debug option defaults to TeX';

$plan = OLLM::CLI->parse(qw(standalone classpath=../tex));
is_deeply $plan->{legacy_args}, ['+standalone', '+classpath=../tex'],
  'legacy standalone options are preserved';

$plan = OLLM::CLI->parse(qw(script lang=en debug -silent main.tex));
is_deeply(
  [OLLM::CLI->_legacy_command($plan, '/tmp/ollm-legacy.rc')],
  [
    'latexmk', '-norc', '-r', '/tmp/ollm-legacy.rc',
    '+script', '+lang=en', '+debug', '-silent', 'main.tex',
  ],
  'legacy build uses an argument list without shell interpolation',
);

eval { OLLM::CLI->parse(qw(slides script)) };
like $@, qr/more than one document target/, 'conflicting targets rejected';

eval { OLLM::CLI->parse(qw(script -r project.rc)) };
like $@, qr/additional rc files.*controlled build configuration/,
  'two-argument latexmk rc injection is rejected by the CLI parser';

done_testing;
