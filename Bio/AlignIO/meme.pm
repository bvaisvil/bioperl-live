# $Id$
#
#  BioPerl module for Bio::AlignIO::meme
#	based on the Bio::SeqIO modules
#  by Ewan Birney <birney@sanger.ac.uk>
#  and Lincoln Stein  <lstein@cshl.org>
#  and the SimpleAlign.pm module of Ewan Birney
#
# Copyright Benjamin Berman
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::AlignIO::meme - meme sequence input/output stream

=head1 SYNOPSIS

Do not use this module directly.  Use it via the Bio::AlignIO class.

=head1 DESCRIPTION

This object transforms the "sites sorted by p-value" sections of a meme
(text) output file into a series of Bio::SimpleAlign objects.  Each
SimpleAlign object contains Bio::LocatableSeq objects which represent the
individual aligned sites as defined by the central portion of the "site"
field in the meme file.  The start and end coordinates are derived from
the "Start" field. See L<Bio::SimpleAlign> and L<Bio::LocatableSeq> for
more information.

This module can only parse MEME version 3.0 and greater.  Previous 
versions have output formats that are more difficult to parse 
correctly.  If the meme output file is not version 3.0 or greater, 
we signal an error.

=head1 FEEDBACK

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.
Bug reports can be submitted via email or the web:

 bioperl-bugs@bio.perl.org
 http://bugzilla.bioperl.org/

=head1 AUTHORS - Benjamin Berman

 (based on the Bio::SeqIO modules by Ewan Birney and others)
 Email: benb@fruitfly.berkeley.edu

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with an
underscore.

=cut

# Let the code begin...

package Bio::AlignIO::meme;
use vars qw(@ISA);
use strict;

use Bio::AlignIO;
use Bio::LocatableSeq;

@ISA = qw(Bio::AlignIO);

# Constants
my $MEME_VERS_ERR = 
"MEME output file must be generated by version 3.0 or higher";
my $MEME_NO_HEADER_ERR = 
"MEME output file contains no header line (ex: MEME version 3.0)";
my $HTML_VERS_ERR = 
"MEME output file must be generated with the -text option";

=head2 next_aln

 Title   : next_aln
 Usage   : $aln = $stream->next_aln()
 Function: returns the next alignment in the stream
 Returns : Bio::SimpleAlign object
 Args    : NONE

=cut

sub next_aln {
	my ($self) = @_;
	my $aln =  Bio::SimpleAlign->new(-source => 'meme');
	my $line;
	my $good_align_sec = 0;
	my $in_align_sec = 0;
	while (!$good_align_sec && defined($line = $self->_readline())) {
		if (!$in_align_sec) {
			# Check for the meme header
			if ($line =~ /^\s*MEME\s+version\s+(\S+)/ ){
				$self->{'meme_vers'} = $1;
				$self->throw($MEME_VERS_ERR) unless ($self->{'meme_vers'} >= 3.0);
				$self->{'seen_header'} = 1;
	      }

			# Check if they've output the HTML version
			if ($line =~ /\<TITLE\>/i){
				$self->throw($HTML_VERS_ERR);
	      }

			# Check if we're going into an alignment section
			if ($line =~ /sites sorted by position/) {
				$self->throw($MEME_NO_HEADER_ERR) unless ($self->{'seen_header'});
				$in_align_sec = 1;
			}
		}elsif ($line =~ /^(\S+)\s+(\d+)\s+
                       (\S+)\s+([\.ACTGactg]*)\s+([ACTGactg]+)\s+
                       ([\.ACTGactg]*)/x ) {
			# Got a sequence line
			my $seq_name = $1;
			# my $strand = ($2 eq '+') ? 1 : -1;
			my $start_pos = $2;
			# my $p_val = $3;
			# my $left_flank = uc($4);
			my $central = uc($5);
			# my $right_flank = uc($6);

			# Info about the sequence
			my $seq_res = $central;
			my $seq_len = length($seq_res);

			# Info about the flanking sequence
			# my $left_len = length($left_flank);
			# my $right_len = length($right_flank);
			# my $start_len = ($strand > 0) ? $left_len : $right_len;
			# my $end_len = ($strand > 0) ? $right_len : $left_len;

			# Make the sequence.  Meme gives the start coordinate at the left
			# hand side of the motif relative to the INPUT sequence.
			my $start_coord = $start_pos;
			my $end_coord = $start_coord + $seq_len - 1;
			my $seq = new Bio::LocatableSeq(-seq    => $seq_res,
													  -id     => $seq_name,
													  -start  => $start_coord,
													  -end    => $end_coord,
													  -strand => "+"
													 );

			# Make a seq_feature out of the motif
			$aln->add_seq($seq);
		}elsif (($line =~ /^\-/) || ($line =~ /Sequence name/)){
			# These are acceptable things to be in the site section
		}elsif ($line =~ /^\s*$/){
			# This ends the site section
			$in_align_sec = 0;
			$good_align_sec = 1;
		}else{
			$self->warn("Unrecognized format:\n$line");
			return 0;
		}
	}

	# Signal an error if we didn't find a header section
	$self->throw($MEME_NO_HEADER_ERR) unless ($self->{'seen_header'});

	return (($good_align_sec) ? $aln : 0);
}

=head2 write_aln

 Title   : write_aln
 Usage   : $stream->write_aln(@aln)
 Function: Not implemented
 Returns : 1 for success and 0 for error
 Args    : Bio::SimpleAlign object

=cut

sub write_aln {
   my ($self,@aln) = @_;

   # Don't handle it yet.
   $self->throw("AlignIO::meme::write_aln not implemented");
   return 0;
}

# ----------------------------------------
# -   Private methods
# ----------------------------------------

sub _initialize {
  my($self,@args) = @_;

  # Call into our base version
  $self->SUPER::_initialize(@args);

  # Then initialize our data variables
  $self->{'seen_header'} = 0;
}

1;
