
=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Xrefs::CoordinateMapping

=cut

=head1 DESCRIPTION

Mapping class that runs the coordinate mapping.

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::CoordinateMapping;

use strict;
use warnings;

use Bio::EnsEMBL::Xref::Mapper::CoordinateMapper;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

=head2 run
  Runner for CoordinateMpping analysis. 
  Initialize CoordinateMapper with xref and core db adaptors and call run_coordinatemapping. 
  Ensure dir pointed by base_path exists
=cut

sub run {
  my ($self)    = @_;
  my $xref_url  = $self->param_required('xref_url');
  my $species   = $self->param_required('species');
  my $base_path = $self->param_required('base_path');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  # get xref db adaptor
  my $xref_dba = $self->get_xref_dba($xref_url);

  # get core db adaptor
  my $registry = 'Bio::EnsEMBL::Registry';
  my $core_dba = $registry->get_DBAdaptor( $species, 'core' );

# initialize CoordinateMapper with xref and core db adaptors and call run_coordinatemapping
  my $coord = Bio::EnsEMBL::Xref::Mapper::CoordinateMapper->new( $xref_dba, $core_dba );
  my $species_id = $self->get_taxon_id($species);
  $coord->run_coordinatemapping( 1, $species_id, $base_path );

}

1;

