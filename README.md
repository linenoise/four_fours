Four Fours
==========

The game goes like this:

* Construct the numbers 1 through 100 using equations that contain exactly four 4s.
* You may use any integer mathemtaical operator: addition, multiplication, etc.
* The base of a logarithm and the degree of a root must be accounted for (and not assumed to be 2, e, 10, or the something else other than one of your four fours).

For example:

1. (4 + 4) / (4 + 4)
2. (4 * 4) / (4 + 4)
3. (4 + 4 + 4) / 4

Running
-------

Run the perl script as `./four_fours.pl`. It will produce a series of text files containing game data. For example, `game_4.txt` for four fours (as opposed to `game_3.txt for three threes, etc) should contain:

		0: 389 solutions available. First found: add(4,subtract(4,add(4,4)))
		1: 254 solutions available. First found: divide(4,modulus(4,add(4,4)))
		2: 32 solutions available. First found: multiply(4,divide(4,add(4,4)))
		3: 19 solutions available. First found: subtract(4,exponent(4,subtract(4,4)))
		4: 127 solutions available. First found: modulus(4,add(4,add(4,4)))
		5: 22 solutions available. First found: add(4,exponent(4,subtract(4,4)))
		6: 9 solutions available. First found: add(4,divide(add(4,4),4))
		7: 8 solutions available. First found: add(4,subtract(4,divide(4,4)))
		8: 89 solutions available. First found: subtract(4,subtract(4,add(4,4)))
		9: 12 solutions available. First found: add(4,add(4,divide(4,4)))
		... and so on.

