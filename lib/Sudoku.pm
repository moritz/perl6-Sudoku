use v6;

class Sudoku::Constraint {
    has @.x;
    has @.y;  # ;;
    has %.remaining-symbols handles delete-symbol => 'delete';
    method xy() { @!x Z @!y };
    method Str {
        '    Constraint: x(' ~ @!x ~ '); y(' ~ @!y ~ ') '
            ~ %!remaining-symbols.keys.sort
            ~ "\n";
    }
}

class Sudoku {
    has $.block-size = 3;
    has $.size = $.block-size ** 2;
    has @!rows;
    has @!coverage;

    has @!constraints;

    has @!available;

    method from-string($s) {
        my $o = self.new(
            rows      => (^9).map({[0 xx 9]}),
            available => (^9).map({[(^9).map: { [ True xx 9 ]}]}),
        );
        $o.init();
        for ^$o.size X ^$o.size -> $y, $x {
            my $i = 9 * $y + $x;
            if $s.substr($i, 1) -> $char {
                $o.add-hint($char, :$x, :$y);
            }
        }
        $o;
    }

    method Str {
        @!rows.map({ .map({ $_ == 0 ?? '.' !! $_ }).join ~ "\n" }).join;
    }

    method add-hint($n, :$x, :$y) {
#        say "Adding hint $n at ($x, $y)";
        given @!rows[$y][$x] {
            if  $_ && $_ !== $n {
                die "Trying to set ($x, $y) to $n, but it is already set (to $_)";
            } elsif $_ {
#                say "... but it's already there";
                return;
            }
        }
        @!rows[$y][$x] = $n;
        @!available[$y][$x][$_] = False for ^$!size;
        for @(@!coverage[$y][$x]) -> $c {
            $c.delete-symbol($n);
            for $c.xy -> $mx, $my {
                @!available[$my][$mx][$n - 1] = False;
            }
        }
    }

    method init() {
        for ^$!size {
            # rows
            @!constraints.push: Sudoku::Constraint.new(
                x => ^$.size,
                y => $_ xx $!size,
                remaining-symbols => hash( 1..$!size Z=> True xx * ),
            );
            # columns
            @!constraints.push: Sudoku::Constraint.new(
                x => $_ xx $.size,
                y => ^$.size,
                remaining-symbols => hash( 1..$!size Z=> True xx * ),
            );
        }
        for ^$!block-size X ^$!block-size -> $x, $y {
            # blocks
            @!constraints.push: Sudoku::Constraint.new(
                x => (^$!block-size X+ ($x * $!block-size)) xx $!block-size,
                y => ((^$!block-size Xxx $!block-size )X+ ($y * $!block-size)),
                remaining-symbols => hash( 1..$!size Z=> True xx * ),
            );
        }
        for @!constraints -> $c {
            for $c.xy -> $x, $y {
                @!coverage[$y][$x] //= [];
                @!coverage[$y][$x].push: $c;
            }
        }
    }

    method solve() {
        $.simple-fill();
    }

    method simple-fill() {
        for ^$!size X ^$!size -> $x, $y {
            if 1 == [+] @(@!available[$y][$x]) {
                # just one number allowed here... find it
                for ^$!size -> $n {
                    if @!available[$y][$x][$n] {
                        $.add-hint($n + 1, :$x, :$y);
                        last;
                    }
                }
            }
        }

        for @!constraints -> $c {
            my @rc = $c.remaining-symbols.keys;
            if @rc == 1 {
                # just one remaining symbol
                # find out where it is
                for $c.xy -> $x, $y {
                    if @!rows[$y][$x] == 0 {
#                        warn "Adding @rc[0] to ($x, $y)";
                        $.add-hint(@rc[0], :$x, :$y);
                        last;
                    }
                }
            }
        }
    }
}

# vim: ft=perl6
