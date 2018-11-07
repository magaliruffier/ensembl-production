=head1 LICENSE

Copyright [2009-2015] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ParseSource;

use strict;
use warnings;

use Carp;

use File::Basename;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $parser = $self->make_parser({ parser       => $self->param_required('parser'),
				    species      => $self->param_required('species'),
				    species_id   => $self->param_required('species_id'),
				    file_name    => $self->param_required('file_name'),
				    source_id    => $self->param_required('source'),
				    xref_url     => $self->param_required('xref_url'),
				    db           => $self->param('db'),
				    release_file => $self->param('release_file') });

  eval { $parser->run(); };
  croak sprintf("Parsing %s source failed: $@", $self->param('parser')) if $@;

  $self->cleanup_DBAdaptor($self->params('db')) if defined $self->param('db');
}

=head2 make_parser

Factory method: instantiate requested parser

=cut

sub make_parser {
  my ($self, $params) = @_;

  my $module = "Bio::EnsEMBL::Xref::Parser::" . $params->{parser};
  eval "require $module";
  croak "Unable to instantiate parser: $@" if $@;

  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($params->{xref_url});
  my %args =
    (
     source_id  => $params->{source_id},
     species_id => $params->{species_id},
     species    => $params->{species},
     rel_file   => $params->{release_file} // undef,
     files      => [ $params->{file_name} ],
     xref_dba   => Bio::EnsEMBL::Xref::DBSQL::BaseAdaptor->new(host    => $host,
								dbname  => $dbname,
								port    => $port,
								user    => $user,
								pass    => $pass ),
     verbose    => 1
    );

  if (defined $params->{db}) {
    my $registry = 'Bio::EnsEMBL::Registry';
    
    $args{dba} = $registry->get_DBAdaptor($params->{species}, $params->{db});
    $args{dba}->dbc->disconnect_if_idle();
  }
  
  return $module->new(%args);
}

1;

