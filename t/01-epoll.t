use strict;
use Sys::Syscall ':epoll';
use Test::More;
use POSIX;

my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();

print "v=$version\n";

if ($^O ne 'linux' || $version =~ /^2\.[01234]\./) {
    non_linux_26();
}

plan tests => 18;
ok(Sys::Syscall::epoll_defined(), "have epoll");

my $epfd = epoll_create();
ok($epfd >= 0, "did epoll_create");

ok(EPOLLHUP && EPOLLIN && EPOLLOUT && EPOLLERR,     "epoll masks");
ok(EPOLL_CTL_ADD && EPOLL_CTL_DEL && EPOLL_CTL_MOD, "epoll_ctl constants");

is(epoll_ctl($epfd, EPOLL_CTL_ADD, fileno(STDOUT), EPOLLOUT), 0, "epoll_ctl stdout EPOLLOUT");

my $events = [];
is(epoll_wait($epfd, 1, 500, $events), 1, "epoll_wait");
my $ev = $events->[0];
ok(ref $ev eq "ARRAY", "got an array in our event");
$ev ||= [];
is($ev->[0], fileno(STDOUT), "event is stdout");
is($ev->[1], EPOLLOUT, "stdout is writable");

is(epoll_ctl($epfd, EPOLL_CTL_MOD, fileno(STDOUT), EPOLLIN), 0, "epoll_ctl mod stdout readable?");
my ($t1, $t2);
$t1 = time();
is(epoll_wait($epfd, 1, 1000, $events), 0, "epoll_wait");
$t2 = time();
ok($t2 > $t1 && $t2 < ($t1 + 3), "took a second");

is(epoll_ctl($epfd, EPOLL_CTL_MOD, fileno(STDOUT), EPOLLOUT), 0, "epoll_ctl stdout writable");
is(epoll_ctl($epfd, EPOLL_CTL_ADD, fileno(STDERR), EPOLLOUT), 0, "epoll_ctl stderr writable");
is(epoll_wait($epfd, 2, 500, $events), 2, "epoll_wait");
ok(($events->[0][0] == fileno(STDOUT) && $events->[1][0] == fileno(STDERR)) ||
   ($events->[1][0] == fileno(STDOUT) && $events->[0][0] == fileno(STDERR)), "got both");

is(epoll_ctl($epfd, EPOLL_CTL_DEL, fileno(STDOUT), 0), 0, "epoll_ctl del stdout");
ok(epoll_ctl($epfd, EPOLL_CTL_MOD, fileno(STDOUT), 0), "epoll_ctl on bad fd");

sub non_linux_26 {
    plan tests => 1;
    ok(! Sys::Syscall::epoll_defined());
    exit 0;
}

