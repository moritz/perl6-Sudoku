use v6;

class Sudoku::Constraint {
    has @.x;
    has @.y;  # ;;
    has %.remaining-symbols handles delete-symbol => 'delete';
}

class Sudoku {
    has $.block-size = 3;
    has $.size = $.block-size ** 2;
    has @.rows;

    has @!maybe;
    has @!constraints;

    method from-string($s) {
        my $o = self.new(rows => $s.comb(/.**9/).map: { [ .comb.map: +* ] });
        $o.init();
        $o;
    }

    method Str {
        @!rows.map({ .map({ $_ == 0 ?? '.' !! $_ }).join ~ "\n" }).join;
    }

    method add-number($n, :$x, :$y) {
        given @!rows[$y][$x] {
            if  $_ && $_ !== $n {
                die "Trying to set ($x, $y) to $n, but it is already set (to $_)";
            }
        }
        @!constraints[$y][$y] = [0 xx $!size];
        for ^$!size {
            @!constraints[$y][$_][$n - 1] = 0;
            @!constraints[$_][$x][$n - 1] = 0;
        }
    }

    method init() {
        for ^$!size X ^$!size -> $x, $y {
            @!constraints[$y][$x] = [ True xx $!size ];
        }
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
            @!constraints.push: Sudoku::Constraint.new(
                x => (^$!block-size X+ ($x * $!block-size)) xx $!block-size,
                y => ((^$!block-size Xxx $!block-size )X+ ($y * $!block-size)),
                remaining-symbols => hash( 1..$!size Z=> True xx * ),
            );
        }
    }
}

# vim: ft=perl6
