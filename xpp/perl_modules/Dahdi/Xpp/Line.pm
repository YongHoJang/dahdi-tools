package Dahdi::Xpp::Line;
#
# Written by Oron Peled <oron@actcom.co.il>
# Copyright (C) 2008, Xorcom
# This program is free software; you can redistribute and/or
# modify it under the same terms as Perl itself.
#
# $Id$
#
use strict;
use Dahdi::Utils;

sub new($$$) {
	my $pack = shift or die "Wasn't called as a class method\n";
	my $xpd = shift or die;
	my $index = shift;
	defined $index or die;
	my $self = {};
	bless $self, $pack;
	$self->{XPD} = $xpd;
	$self->{INDEX} = $index;
	return $self;
}

sub blink($$) {
	my $self = shift;
	my $on = shift;
	my $xpd = $self->xpd;
	my $result;
	my $file = Dahdi::Xpp::xpd_attr_path(
			$xpd->xbus->num,
			$xpd->unit,
			$xpd->subunit, "blink");
	die "$file is missing" unless -f $file;
	# First query
	open(F, "$file") or die "Failed to open $file for reading: $!";
	$result = <F>;
	chomp $result;
	close F;
	$result = hex($result);
	if(defined($on)) {		# Now change
		my $onbitmask = 1 << $self->index;
		my $offbitmask = $result & ~$onbitmask;

		$result = $offbitmask;
		$result |= $onbitmask if $on;
		open(F, ">$file") or die "Failed to open $file for writing: $!";
		print F "$result";
		if(!close(F)) {
			if($! == 17) {	# EEXISTS
				# good
			} else {
				undef $result;
			}
		}
	}
	return $result;
}

sub create_all($$) {
	my $pack = shift or die "Wasn't called as a class method\n";
	my $xpd = shift || die;
	my $procdir = shift || die;
	local $/ = "\n";
	my @lines;
	for(my $i = 0; $i < $xpd->{CHANNELS}; $i++) {
		my $line = Dahdi::Xpp::Line->new($xpd, $i);
		push(@lines, $line);
	}
	$xpd->{LINES} = \@lines;
	if($xpd->type eq 'FXO') {
		my $file = Dahdi::Xpp::xpd_attr_path(
				$xpd->xbus->num,
				$xpd->unit,
				$xpd->subunit, "fxo_battery");
		if(defined $file) {
			open(F, "$file") || die "Failed opening '$file': $!";
			my $battery_line = <F>;
			close F;
			my @batt = split(/\s+/, $battery_line);
			foreach my $l (@lines) {
				die unless @batt;
				my $state = shift @batt;
				$l->{BATTERY} = ($state eq '+') ? 1 : 0;
			}
		} else {
			# Fallback to old interface
			my ($infofile) = glob "$procdir/*_info";
			die "Failed globbing '$procdir/*_info'" unless defined $infofile;
			open(F, "$infofile") || die "Failed opening '$infofile': $!";
			my $battery_info = 0;
			while (<F>) {
				chomp;
				$battery_info = 1 if /^Battery:/;
				if($battery_info && s/^\s*on\s*:\s*//) {
					my @batt = split;
					foreach my $l (@lines) {
						die unless @batt;
						my $state = shift @batt;
						$l->{BATTERY} = ($state eq '+') ? 1 : 0;
					}
					$battery_info = 0;
					die if @batt;
				}
			}
			close F;
		}
	}
	close F;
}


1;
