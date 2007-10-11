#!/usr/bin/perl -w
use strict;
use DBI;
use Scriptalicious;

my $dbh = DBI->connect("dbi:Pg:", "", "", {PrintError => 1}) or die $DBI::errstr;

do_integed_compare($dbh);

sub do_integed_compare {
	my $dbh = shift;
	my $sth = $dbh->prepare(<<SQL);
select
	depotpath,
	md5(depotpath)
from
	(select distinct
		depotpath
	from
		rev) x
order by
	md5(depotpath)
SQL

	$sth->execute;

	$| = 1;

	my ($ok, $total);
	while ( my ($depotpath) = $sth->fetchrow_array ) {
		print "\r$depotpath\e[K";
		run(-out => "p4-integed",
		    "p4", "integrated", $depotpath);
		run(-out => "p4raw-integed",
		    "git-p4raw", "integrated", $depotpath);

		if ( run_err("diff", "-q", "p4-integed", "p4raw-integed") ) {
			print "...different\n";
			if ( prompt_yN("see?") ) {
				system("diff", "-u", "p4-integed", "p4raw-integed");
			}
		}
		else {
			$ok++;
		}
		unless ( ++$total % 100 ) {
			print " $ok / $total good\e[K\n";
		}
	}
	print "\n";
	print "checked $total files, $ok good\n";
}

