use v5.30;
use strict;
use warnings;

use Test::More;
use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

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

$plan = OLLM::CLI->parse(qw(
  clean --level=state --scope=unit --target=script --language=de --dry-run
));
is $plan->{action}, 'clean', 'clean is a first-class action';
is $plan->{level}, 'state', 'clean level is parsed';
is $plan->{scope}, 'unit', 'clean scope is parsed';
is $plan->{target}, 'script', 'current projection target is parsed';

$plan = OLLM::CLI->parse(qw(prune --stale-units --dry-run));
ok $plan->{stale_units}, 'explicit stale-unit pruning is parsed';

$plan = OLLM::CLI->parse(qw(report --scope=unit --format=json));
is $plan->{action}, 'report', 'report is a first-class action';
is $plan->{scope}, 'unit', 'report scope is parsed';

$plan = OLLM::CLI->parse(qw(check --target=script --language=de));
is $plan->{action}, 'check', 'check is a first-class action';
is $plan->{target}, 'script', 'check current target is parsed';

$plan = OLLM::CLI->parse(qw(--legacy +build +script));
ok $plan->{legacy}, '--legacy is explicit in the normalized plan';
is $plan->{target}, 'script', 'plus-prefixed command and target are accepted';

$plan = OLLM::CLI->parse(qw(--enforce+ +build +script));
ok $plan->{enforce_plus}, '--enforce+ enables mandatory prefixes';
is $plan->{action}, 'build', 'prefixed action is recognized under enforcement';
is $plan->{target}, 'script', 'prefixed target is recognized under enforcement';

$plan = OLLM::CLI->parse(qw(+enforce+ +script slides));
is $plan->{target}, 'script', '+enforce+ enables the same mode';
is $plan->{source}, 'slides', 'bare target word becomes a source under enforcement';

$plan = OLLM::CLI->parse(qw(+convertconfig));
is $plan->{action}, 'convertconfig', 'migration command accepts a plus prefix';

eval { OLLM::CLI->parse(qw(clean --level=unknown)) };
like $@, qr/invalid --level/, 'unknown clean level is rejected';

done_testing;
