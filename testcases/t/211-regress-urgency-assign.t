#!perl
# vim:ts=4:sw=4:expandtab
#
# Please read the following documents before working on tests:
# • http://build.i3wm.org/docs/testsuite.html
#   (or docs/testsuite)
#
# • http://build.i3wm.org/docs/lib-i3test.html
#   (alternatively: perldoc ./testcases/lib/i3test.pm)
#
# • http://build.i3wm.org/docs/ipc.html
#   (or docs/ipc)
#
# • http://onyxneon.com/books/modern_perl/modern_perl_a4.pdf
#   (unless you are already familiar with Perl)
#
# Verifies that windows are properly recognized as urgent when they start up
# with the urgency hint already set (and are assigned to a non-visible
# workspace).
#
# Ticket: #1086
# Bug still in: 4.6-62-g7098ef6
use i3test i3_autostart => 0;
use X11::XCB qw(:all);

# TODO: move to X11::XCB
sub set_wm_class {
    my ($id, $class, $instance) = @_;

    # Add a _NET_WM_STRUT_PARTIAL hint
    my $atomname = $x->atom(name => 'WM_CLASS');
    my $atomtype = $x->atom(name => 'STRING');

    $x->change_property(
        PROP_MODE_REPLACE,
        $id,
        $atomname->id,
        $atomtype->id,
        8,
        length($class) + length($instance) + 2,
        "$instance\x00$class\x00"
    );
}

sub open_special {
    my %args = @_;
    my $wm_class = delete($args{wm_class}) || 'special';
    $args{name} //= 'special window';

    # We use dont_map because i3 will not map the window on the current
    # workspace. Thus, open_window would time out in wait_for_map (2 seconds).
    my $window = open_window(
        %args,
        before_map => sub { set_wm_class($_->id, $wm_class, $wm_class) },
        dont_map => 1,
    );
    $window->add_hint('urgency');
    $window->map;
    return $window;
}

my $config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

assign [class="special"] nonvisible
EOT
my $pid = launch_with_config($config);

my $tmp = fresh_workspace;

ok((scalar grep { $_ eq 'nonvisible' } @{get_workspace_names()}) == 0,
   'assignment destination workspace does not exist yet');

my $window = open_special;
sync_with_i3;

ok((scalar grep { $_ eq 'nonvisible' } @{get_workspace_names()}) > 0,
   'assignment destination workspace exists');

my @urgent = grep { $_->{urgent} } @{get_ws_content('nonvisible')};
isnt(@urgent, 0, 'urgent window(s) found on destination workspace');

exit_gracefully($pid);

done_testing;
