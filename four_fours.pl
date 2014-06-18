#!/usr/bin/perl -w
use strict;

###
# fourfours.pl
#
# Determines a solution set to the four fours game.
# By Dann Stayskal <dann@stayskal.com> http://dann.stayskal.com/
# Released under MIT license.
#
# Here's the game:
# * Construct the numbers 1 through 100 using equations that contain exactly four 4s.
# * You may use any integer mathemtaical operator: addition, multiplication, etc.
# * The base of a logarithm and the degree of a root must be accounted for (and not
#   assumed to be 2, e, 10, or the something else other than one of your four fours).
#
# This program plays that game.
#
# Example:
# 1: (4 + 4) / (4 + 4)
# 2: (4 * 4) / (4 + 4)
# 3: (4 + 4 + 4) / 4
#    ... and so on.
###

# Set $verbose to get more output while the game is running:
# 0 = No messages printed other than the final output
# 1 = Include tree-level information
# 2 = Include expression-level information
# 3 = Include symbolic processing information
my $verbose = 0;

### 
# The expressions table, an array of hashes containing:
# * 'operation', a short string name for the operation
# * 'do', a routine that performs the operation (and may return 'unknown')
###
my @expressions = (
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
			return 'unknown' if $_[1] == 0;
			return $_[0] / $_[1];
		},
	},
	{
		'operation' => 'modulus',
		'do' => sub { 
			return 'unknown' if $_[1] == 0 || (int($_[1]) != $_[1]);
			return $_[0] % $_[1];
		},
	},
	{
		'operation' => 'log',
		'do' => sub { 
			return 'unknown' if $_[0] <= 0 || $_[1] <= 0 || $_[1] == 1;
			return log($_[0]) / log($_[1]);
		},
	},
	{
		'operation' => 'root',
		'do' => sub { 
			return 'unknown' if $_[1] == 0;
			return $_[0] ** (1/$_[1]);
		},
	}
);

###
# Play the games.
#
# 1. Figure out how many nodes each tree will have
# 2. Generate each valid tree shape (branches and leaves)
# 3. Populate that tree's branches with each combination of expressions 
#    and leaves with the game being played (e.g. '4')
# 4. Run each tree and hash the resulting value with the valid tree that produced it
# 5. Print off the results hash with number of solutions for each result value
###

### Actually, let's play lots of games.
my $playing_started_at = time();
open('GAME_SCORES', '>', 'game_scores.txt') || die "Can't open game_scores.txt for writing.";
foreach my $game (2..7){
	
	my $game_started_at = time();
	open('THIS_GAME', '>', "game_$game.txt") || die "Can't open game_$game.txt for writing.";
	
	###
	# 1. Figure out how many nodes each tree will have
	#
	# We know that all syntactically valid trees will have (2 * $game) - 1 nodes
	#   * Four fours trees will have seven nodes,
	#   * Five fives trees will have nine nodes, etc.
	# And of these nodes, $game - 1 will be branches, and $game will be leaves.
	###
	my $nodes_per_tree = (2 * $game) - 1;
	my $branches_per_tree = $game - 1;
	my $leaves_per_tree = $game;
	my $max_expression = scalar(@expressions) - 1;
	my $game_board = {};
	if($verbose){
		print "Playing game: $game\n";
		print "Nodes per tree: $nodes_per_tree\n";
		print "Branches per tree: $branches_per_tree\n";
		print "Leaves per tree: $leaves_per_tree\n";
		print "Max expression: $max_expression\n";
	}

	###
	# 2. Generate each valid tree shape (branches and leaves)
	#
	# Every binary tree shape can be represented in binary using prefix traversal:
	#   1 for branches
	#   0 for leaves
	# To generate all binary tree shapes for this game, count from 0 up to 2 ** $nodes_per_tree.
	###
	for (my $tree_shape = 0; $tree_shape < (2 ** $nodes_per_tree); $tree_shape++) {
	
		# Convert the tree shape from decimal to binary
		my $binary_shape = sprintf '%0'.$nodes_per_tree.'b', $tree_shape; # Looks like '0101010'

		# Convert that into a binary array
		my @shape_map = split(//,$binary_shape);

		# Not all binary trees are valid for this game. Only the ones with exactly $game leaves
		# are going to use exactly four fours, five fives, etc. Prune many invalid shapes by 
		# adding the binary digits of the shape map. A well-formed tree has $game - 1 branches.
		my $branch_count = 0;
		foreach my $node (@shape_map) {
			$branch_count += $node;
		}
		next unless $branch_count == $branches_per_tree;
	
		# Build a data structure corresponding to this shape map.
		my $tree_structure = tree_structure_for(\@shape_map);
	
		# Count the leaves in the tree structure. If there aren't exactly $game leaves, skip it.
		my $leaf_count = count_leaves_in($tree_structure);
		next unless $leaf_count == $game;
		if ($verbose >= 1) {
			print "   Calculating for tree shape: $binary_shape\n";
		}
	
		###
		# 3. Populate that tree's branches with each combination of expressions 
		#    and leaves with the game being played (e.g. '4')
		#
		# This is done through an expression map--an array of three integers corresponding to
		# which expression will be applied to which branch. Iterate this expression map 
		# sequentially while further expression combinations are available.
		###
		my @expression_map = ();
		foreach (0..$branches_per_tree-1) {
			push @expression_map, 0;
		}
		my $expressions_have_been_exhausted = 0;
		until ($expressions_have_been_exhausted) {
		
			# Apply this expression map to the provided tree structure
			my @expression_cache = @expression_map;
			my $tree = apply_expression_map($tree_structure, \@expression_cache, $game);
		
			# Describe this binary tree in infix notation
			my $tree_description = describe_tree($tree);
		
			###
			# 4. Run each tree and hash the resulting value with the valid tree that produced it
			#
			# In this case, our hash is the description of the tree. This and the value get
			# stored in $game_board (if the value is an integer) for us to tally up later.
			###
		
			# Calculate the value represented by this binary expression tree.
			my $tree_value = calculate_tree($tree);
			if ($verbose >= 2) {
				print "      Tree $tree_description represents $tree_value\n";
			}
			if ($tree_value ne 'unknown' && $tree_value == int($tree_value)) {
				$game_board->{$tree_value} ||= [];
				push @{$game_board->{$tree_value}}, $tree_description;
			}
		
			# Increment the expression map
			$expression_map[0]++;
			foreach my $i (0..scalar(@expression_map)-1) {
				if ($expression_map[$i] > $max_expression) {
					if ($i == $branches_per_tree-1) {
						$expressions_have_been_exhausted = 1;
					} else {
						$expression_map[$i] = 0;
						$expression_map[$i+1]++;
					}
				}
			}
		}
	}

	###
	# 5. Print off the results hash with number of solutions for each result value
	###
	my @solutions = ();
	foreach my $number (0..10000){
		if ($game_board->{$number}) {
			my $solutions = scalar(@{$game_board->{$number}});
			push @solutions, $solutions;
			print THIS_GAME "$number: $solutions solutions available. First found: ";
			print THIS_GAME $game_board->{$number}->[0]."\n";
		} else {
			print THIS_GAME "$number: No solution available.\n";
			push @solutions, 0;
		}
	}
	print GAME_SCORES join(', ', @solutions)."\n";
	close('THIS_GAME');
	
	my $game_duration = time() - $game_started_at;
	print "All variations of game $game exhausted in $game_duration seconds.\n";
}
close('GAME_SCORES');

my $playing_duration = time() - $playing_started_at;
print "Available games exhausted in $playing_duration seconds.\n";


######
### Routines for working with binary trees and expression maps
######

###
# &apply_expression_map
# Merges an expression map with a tree structure
#
# Takes:
#   $tree_structure, the known well-formed tree structure
#   $expression_cache, a cache of the current expression map that we can destroy
#   $game, the current game we're playing
# Returns:
#   $binary_tree, the binary expression tree for this structure and map combination
###
sub apply_expression_map {
	my ($tree_structure, $expression_cache, $game) = @_;
	
	if (ref($tree_structure) eq 'ARRAY') {
		my $expression = shift(@$expression_cache);
		my $values = [];
		foreach my $subtree (@$tree_structure){
			push @$values, apply_expression_map($subtree, $expression_cache, $game);
		}
		return {
			'expression' => $expressions[$expression],
			'values' => $values
		};
	} else {
		return $game;
	}
}


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
		
		return "$operation($a,$b)"
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
		
		
		# Determine what's on the right and left
		my $a = calculate_tree($tree->{'values'}->[0]);
		my $b = calculate_tree($tree->{'values'}->[1]);

		# Check for undefined results
		if ($a eq 'unknown' || $b eq 'unknown') {
			return 'unknown';
		} else {
			# Clear to continue with the calculation.
			if ($verbose >= 3) {
				print "         ".$tree->{'expression'}->{'operation'}." $a, $b\n";
			}
			return $tree->{'expression'}->{'do'}->($a,$b);
		}
	} else {
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