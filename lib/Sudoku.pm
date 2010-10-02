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
    has $.stuck = False;

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

    method check() {
        for ^$!size X ^$!size -> $x, $y {
            if @!rows[$y][$x] == 0 && none(@(@!available[$y][$x])) {
                die "Stuck here at ($x, $y), no meaningful way out!";
            }
        }
    }

    method is-solved() {
        for @!rows {
            return False if any(@($_)) == 0;
        }
        True;
    }

    method Str {
        @!rows.map({ .map({ $_ == 0 ?? '.' !! $_ }).join ~ "\n" }).join;
    }

    # returns a data structure that can be turned into SVG with
    # the SVG module from http://github.com/moritz/svg/
    # like this:
    #
    # say SVG.serialize: 'svg' => [
    #       width  => 310,
    #       height => 310,
    #       $sudoku.SVG-tree,
    #   ];
    method SVG-tree(:$output-size = 304, :$line-width=1) {
        my $offset      = 2 * $line-width;
        my $upto        = $output-size - $offset;
        my $line-length = $output-size - 2 * $offset;
        my $cell        = $line-length / $!size;
        gather {
            for 1..^$!size {
                my $stroke-width = $line-width;
                my $color = 'grey';
                if $_ %% $!block-size {
                    $stroke-width *= 1.5;
                    $color = 'black';
                }
                # horizontal grid
                take 'line' => [
                    x1 => $offset,
                    x2 => $upto,
                    y1 => ($offset + $_ / $!size * $line-length),
                    y2 => ($offset + $_ / $!size * $line-length),
                    stroke => $color,
                    :$stroke-width,
                ];
                # horizontal grid
                take 'line' => [
                    y1 => $offset,
                    y2 => $upto,
                    x1 => ($offset + $_ / $!size * $line-length),
                    x2 => ($offset + $_ / $!size * $line-length),
                    stroke => $color,
                    :$stroke-width,
                ];
            }

            # outer frame
            take 'rect' => [
                x => $offset,
                y => $offset,
                width  => $line-length,
                height => $line-length,
                stroke-width => 2.3 * $line-width,
                stroke => 'black',
                fill   => 'none'
            ];

            # numbers
            for ^$!size X ^$!size -> $y, $x {
                if @!rows[$y][$x] -> $symbol {
                    take 'text' => [
                        x => $offset + ($x + 0.5) * $cell,
                        y => $offset + ($y + 0.5) * $cell,
                        text-anchor       => 'middle',
                        dominant-baseline => 'middle',
                        font-weight       => 'bold',
                        $symbol,
                    ];
                }
            }
        }
    }

    method add-hint($n, :$x, :$y) {
        say "Adding hint $n at ($x, $y)";
        given @!rows[$y][$x] {
            if  $_ && $_ !== $n {
                $!stuck = True;
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
        my $track = @!rows.join('|');
        loop {
            $.simple-fill();
            my $new-track = @!rows.join('|');
            last if $track eq $new-track;
            $track = $new-track;
        }
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
