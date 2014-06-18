#!/usr/bin/perl -w
use strict;
use Data::Dumper;
$Data::Dumper::Indent = 1;

###
# fourfours.pl
#
# Determines and graphs a solution set to the four fours game.
# By Dann Stayskal: <dann@stayskal.com> and <http://dann.stayskal.com/>
# Released under MIT license.
#
# Here's the game:
# * Construct the numbers 1 through 100 using equations that contain exactly four 4s.
# * You may use any unary or binary integer mathemtaical operator: addition, factorial, etc.
# * The base of a logarithm and the degree of a root must be accounted for (and not
#   assumed to be 2, e, 10, or the something else other than one of your four fours).
# * You may concatenate your 4s into 44, 444, 4444, etc.
# * You may also add a decimal point, so long as it doesn't also require adding a zero digit
#
# This program plays that game.
#
# Example:
# 1: (4 + 4) / (4 + 4)
# 2: (4 * 4) / (4 + 4)
# 3: (4 + 4 + 4) / 4
#    ... and so on.
#
# References:
# https://en.wikipedia.org/wiki/Binary_expression_tree
###

# Set $verbose to get more output while the game is running:
# 0 = No messages printed other than the final output
# 1 = Include tree-level information
# 2 = Include expression-level information
# 3 = Include symbolic processing information
my $verbose = 1;

# Set $logging to 1 to have results written to game_$n.txt and game_scores.txt
my $logging = 0;

### 
# The expressions tables, two arrays (one for unary, one for binary) of hashes containing:
# * 'operation', a short string name for the operation,
# * 'do', a routine that performs the operation (and may return 'inf')
###
my @unary_expressions = (
	{
		'operation' => 'negate',
		'do' => sub {
			return $_[0] * -1;
		},
	},
	{
		'operation' => 'bar',
		'do' => sub {
			return 'inf' unless length($_[0]) == 1;
			return $_[0] / 9;
		},
	},
	{
		'operation' => 'factorial',
		'do' => sub {
			return 'inf' unless (($_[0] == int($_[0])) && ($_[0] > 0) && ($_[0] < 50));
			my $product = 1;
			$product *= $_[0]-- while $_[0] > 0;
			return $product;
		},
	},
);

my @binary_expressions = (
	{
		'operation' => 'add',
		'do' => sub {
			return $_[0] + $_[1];
		},
	},
	{
		'operation' => 'subtract',
		'do' => sub {
			return $_[0] - $_[1];
		},
	},
	{
		'operation' => 'multiply',
		'do' => sub {
			return $_[0] * $_[1];
		},
	},
	{
		'operation' => 'exponent',
		'do' => sub {
			return $_[0] ** $_[1];
		},
	},
	{
		'operation' => 'divide',
		'do' => sub {
			return 'inf' if $_[1] == 0;
			return $_[0] / $_[1];
		},
	},
	{
		'operation' => 'modulus',
		'do' => sub {
			return 'inf' if $_[1] == 0 || (int($_[1]) != $_[1]);
			return $_[0] % $_[1];
		},
	},
	{
		'operation' => 'log',
		'do' => sub {
			return 'inf' if $_[0] <= 0 || $_[1] <= 0 || $_[1] == 1;
			return log($_[0]) / log($_[1]);
		},
	},
	{
		'operation' => 'root',
		'do' => sub {
			return 'inf' if $_[1] == 0;
			return $_[0] ** (1/$_[1]);
		},
	}
);

###
# Play the game.
#
# 1. Calculate and cache all valid operands
# 2. Fill the cache with all cost-valid arrangements of operators and operands
# 3. Run each tree and hash the resulting value with the valid tree that produced it
# 4. Print off the results hash with number of solutions for each result value
###

my $cache = {};

### Actually, let's play lots of games.
my $playing_started_at = time();
if ($logging) {
	open('GAME_SCORES', '>', 'game_scores.txt') || die "Can't open game_scores.txt for writing.";	
}
foreach my $game (4..4){
	my $game_started_at = time();
	if ($logging) {
		open('THIS_GAME', '>', "game_$game.txt") || die "Can't open game_$game.txt for writing.";
	}
	
	###
	# 1. Calculate and cache all valid operands
	###
	my $game_board = {};
	foreach my $length (1..$game){ 

		# Cache the raw concatenations: 4, 44, 444, etc.
		my $concatenation = ("$game" x $length);
		$cache->{$concatenation} = {
			'cost'  => $length,
			'value' => $concatenation, 
			'tree'  => $concatenation
		};

		# Permit decimal points: 0.4, 0.44, 0.444, etc.
		foreach my $decimal (0..$length){
			my $decimal_value = ($concatenation / (10 ** $decimal));
			$cache->{$decimal_value} = {
				'cost' => $length,
				'value' => $decimal_value, 
				'tree' => $decimal_value
			};
		}
	}
	
	###
	# Here, $cache looks something like this:
	# {
	# 	'44.4' => {
	# 	            'cost' => 3,
	# 	            'tree' => '44.4'
	# 	          },
	# 	'4' => {
	# 	         'cost' => 1,
	# 	         'tree' => '4'
	# 	       },
	# 	...
	# }
	###
	
	###
	# 2. Fill the cache with all cost-valid arrangements of operators and operands:
	###
	my $cache_size = 0;
	# Until the cache size stops changing:
	
	my $counter = 0;
	until ($cache_size == scalar(keys(%$cache))) {
		$cache_size = scalar(keys(%$cache));

		# Calculate and cache all unary functions against everything in the cache   
		foreach my $i (0..scalar(@unary_expressions)-1) {
			foreach my $k (keys(%$cache)){
				
				# Apply unary function $i to value at cache key $k
				my $tree = {
					'expression' => $unary_expressions[$i],
					'values' => [
						$cache->{$k}->{'value'}
					]
				};
				my $description = describe_tree($tree); ### looks like 'negate(4.44)'
				unless ($cache->{$description}) {
					my $value = calculate_tree($tree);

					# Cache the new value. Cost doesn't change.
					unless ($value eq 'inf') {
						if ($verbose >= 1) {
							print "   Caching $description as $value\n";
						}
						$cache->{$description} = {
							'cost'  => $cache->{$k}->{'cost'},
							'value' => $value, 
							'tree' => $tree 
						}
					}
				}
			}
		}
		# print Dumper($cache);
		exit 0 if $counter++ == 2;
		
		
		# Calculate and cache all binary functions against all combinations of what's in the cache

		# Never cache something with a $cost > (2 * $game) + 1;
		
		# Once the cache stops changing, it contains all cost-valid arrangements.
	}
	
	
	# 		###
	# 		# 4. Run each tree and hash the resulting value with the valid tree that produced it
	# 		#
	# 		# In this case, our hash is the description of the tree. This and the value get
	# 		# stored in $game_board (if the value is an integer) for us to tally up later.
	# 		###
	# 	
	# 		# Calculate the value represented by this binary expression tree.
	# 		my $tree_value = calculate_tree($tree);
	# 		if ($verbose >= 2) {
	# 			print "      Tree $tree_description represents $tree_value\n";
	# 		}
	# 		if ($tree_value ne 'inf' && $tree_value == int($tree_value)) {
	# 			$game_board->{$tree_value} ||= [];
	# 			push @{$game_board->{$tree_value}}, $tree_description;
	# 		}
	# 	
	# 		# Increment the expression map
	# 		$expression_map[0]++;
	# 		foreach my $i (0..scalar(@expression_map)-1) {
	# 			if ($expression_map[$i] > $max_expression) {
	# 				if ($i == $branches_per_tree-1) {
	# 					$expressions_have_been_exhausted = 1;
	# 				} else {
	# 					$expression_map[$i] = 0;
	# 					$expression_map[$i+1]++;
	# 				}
	# 			}
	# 		}

	###
	# 5. Print off the results hash with number of solutions for each result value
	###
	my @solutions = ();
	# my $report_start  = -10;
	# my $report_end    = 25;
	# if ($logging) {
	# 	$report_start = -10000;
	# 	$report_end   = 10000;
	# }
	# foreach my $number ($report_start..$report_end){
	# 	my $message = '';
	# 	if ($game_board->{$number}) {
	# 		my $solutions = scalar(@{$game_board->{$number}});
	# 	 	$message = "$number: $solutions solutions available.";
	# 	    $message .= " First found: " . $game_board->{$number}->[0]."\n";
	# 		push @solutions, $solutions;
	# 	} else {
	# 		$message = "$number: No solution available.\n";
	# 		push @solutions, 0;
	# 	}
	# 	if ($logging) {
	# 		print THIS_GAME $message;
	# 	} else {
	# 		print $message;
	# 	}
	# }
	
	my $game_duration = time() - $game_started_at;
	print "\n";
	print "All variations of game $game exhausted in $game_duration seconds.\n";
	if ($logging) {
		print GAME_SCORES join(', ', @solutions)."\n";
		close('THIS_GAME');
	}
}
my $playing_duration = time() - $playing_started_at;
print "All available games exhausted in $playing_duration seconds.\n";
if ($logging) {
	close('GAME_SCORES');
}


######
### Routines for working with binary trees and expression maps
######

###
# &describe_tree
# Produces an infix-traversal description of the given binary expression tree
#
# Takes: $tree, a well-formed binary expression tree
# Returns: $description, a string of characters that conveys this tree to a human
###
sub describe_tree {
	my ($tree) = @_;
	if (ref $tree eq 'HASH') {
		
		my $operation = $tree->{'expression'}->{'operation'};
		
		# Determine what's on the right and left
		my $a = describe_tree($tree->{'values'}->[0]);
		my $b = describe_tree($tree->{'values'}->[1]);
		
		return "$operation(" . 
			join(',',
				map( {describe_tree($_)} @{$tree->{'values'}}
				)
			) . ")";
	} else {
		return $tree;
	}
}


###
# &calculate_tree
# Calculates the value of a binary expression tree
#
# Takes: $tree, a well-formed binary expression tree
# Returns: $value, the value this tree represents algebraically
###
sub calculate_tree {
	my ($tree) = @_;
	if (ref $tree eq 'HASH') {
		my @calculated_values = map({calculate_tree($_)} @{$tree->{'values'}});

		# Check for undefined results
		foreach my $i (0..scalar(@calculated_values)-1){
			if ($calculated_values[$i] eq 'inf') {
				return 'inf';
			}
		}
		if ($verbose >= 3) {
			print((' 'x9).$tree->{'expression'}->{'operation'}.' '.join(', ', @calculated_values) ."\n");
		}

		# Calculate this branch and return.
		return $tree->{'expression'}->{'do'}->(@calculated_values);

	} else {
		# If it's already a value (and not a subtree), return it.
		return $tree;
	}
}


######
### Routines for working with tree structures and shape maps
######

###
# &tree_structure_for
# Recursively generates a tree structure corresponding to a given tree shape map.
#
# Takes: $shape_map, an array reference to the next nodes to incorporate
# Returns: $tree_structure, the structure corresponding to the shape map (on success)
###
sub tree_structure_for {
	my ($shape_map) = @_;
	
	my $node = shift(@$shape_map);
	if ($node == 0) {
		return 'leaf';
	} else {
		return [
			tree_structure_for($shape_map),
			tree_structure_for($shape_map),
		];
	}
}


###
# &count_leaves_in
# Recursively counts the number of leaves in a given tree structure
#
# Takes: $tree_structure with leaves to be counted
# Returns $leaf_count
###
sub count_leaves_in {
	my ($tree_structure) = @_;
	
	if (ref($tree_structure) eq 'ARRAY') {
		my $leaf_count = 0;
		foreach my $subtree (@$tree_structure){
			$leaf_count += count_leaves_in($subtree);
		}
		return $leaf_count;
	} else {
		return 1;
	}
}

exit 0;