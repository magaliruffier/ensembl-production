
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandling_conf

=head1 DESCRIPTION

=head1 AUTHOR 

 dstaines@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandling_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
	my ($self) = @_;
	return {
		## inherit other stuff from the base class
		%{ $self->SUPER::default_options() },

		## General parameters
		'registry'   => $self->o('registry'),
		'release'    => software_version(),
		'eg_version' => undef,
		'ftp_dir'    => '/nfs/nobackup/ensemblgenomes/'
		  . $self->o( 'ENV', 'USER' )
		  . '/workspace/'
		  . $self->o('pipeline_name')
		  . '/ftp_site/release-'
		  . $self->o('release'),
		## dump_fasta parameters
		# types to emit
		'dna_sequence_type_list' => ['dna'],
		'pep_sequence_type_list' => [ 'cdna', 'ncrna' ],

		# Do/Don't process these logic names
		'process_logic_names' => [],
		'skip_logic_names'    => []
	};
}

sub pipeline_create_commands {
	my ($self) = @_;
	return [
		# inheriting database and hive tables' creation
		@{ $self->SUPER::pipeline_create_commands },
		'mkdir -p ' . $self->o('ftp_dir'),
		$self->db_cmd(
'CREATE TABLE result (job_id int(10), output LONGTEXT, PRIMARY KEY (job_id))'
		),
		$self->db_cmd('ALTER TABLE job DROP KEY input_id_stacks_analysis'),
		$self->db_cmd('ALTER TABLE job MODIFY input_id TEXT')
	];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
	  my ($self) = @_;

	  return { %{ $self->SUPER::hive_meta_table },
		  'hive_use_param_stack' => 1, };
}

# Override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
	  my ($self) = @_;
	  return
		' -reg_conf ' . $self->o('registry'),
		;
}

# these parameter values are visible to all analyses,
# can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {
	  my ($self) = @_;
	  return {
		  %{ $self->SUPER::pipeline_wide_parameters }
		  ,    # here we inherit anything from the base class
		  'pipeline_name' => $self->o('pipeline_name')
		  ,    #This must be defined for the beekeeper to work properly
		  'base_path'  => $self->o('ftp_dir'),
		  'release'    => $self->o('release'),
		  'eg_version' => $self->o('eg_version'),
		  'sub_dir'    => $self->o('ftp_dir'),
	  };
}

sub resource_classes {
	  my $self = shift;
	  return {
		  'default' => {
			  'LSF' => '-q production-rh7 -n 4 -M 4000   -R "rusage[mem=4000]"'
		  },
		  '32GB' => {
			  'LSF' => '-q production-rh7 -n 4 -M 32000  -R "rusage[mem=32000]"'
		  },
		  '64GB' => {
			  'LSF' => '-q production-rh7 -n 4 -M 64000  -R "rusage[mem=64000]"'
		  },
		  '128GB' => {
			  'LSF' =>
				'-q production-rh7 -n 4 -M 128000 -R "rusage[mem=128000]"'
		  },
		  '256GB' => {
			  'LSF' =>
				'-q production-rh7 -n 4 -M 256000 -R "rusage[mem=256000]"'
		  },
	  };
}

sub pipeline_analyses {
	  my ($self) = @_;

	  my $pipeline_flow;
	  return [
		  {
			  -logic_name => 'new_assembly_event',
			  -module =>
'Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandler',
			  -hive_capacity   => -1,
			  -rc_name         => 'default',
			  -max_retry_count => 1,
			  -flow_into       => {
				  '1->A' => [ 'dump_fasta_dna', 'dump_fasta_pep' ],
				  'A->1' => ['complete_job']
			  }
		  },
		  {
			  -logic_name => 'new_genebuild_event',
			  -module =>
'Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandler',
			  -hive_capacity   => -1,
			  -rc_name         => 'default',
			  -max_retry_count => 1,
			  -flow_into       => {
				  '1' => ['dump_fasta_pep']
			  }
		  },

		  {
			  -logic_name => 'complete_job',
			  -module =>
'Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandlerCompletion',
			  -meadow_type => 'LOCAL',
			  -parameters  => {},
			  -flow_into   => {
				  2 => ['?table_name=result']
			  }
		  },

### FASTA (cdna, cds, dna, pep, ncrna)
		  {
			  -logic_name => 'dump_fasta_pep',
				-module =>
				'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
				-parameters => {
				  sequence_type_list  => $self->o('pep_sequence_type_list'),
				  process_logic_names => $self->o('process_logic_names'),
				  skip_logic_names    => $self->o('skip_logic_names'),
				},
				-can_be_empty    => 1,
				-max_retry_count => 1,
				-hive_capacity   => 10,
				-priority        => 5,
				-rc_name         => 'default',
		  },

		  {
			  -logic_name   => 'dump_fasta_dna',
			  -module       => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
			  -parameters   => {},
			  -can_be_empty => 1,
			  -flow_into    => {
				  1 => 'dump_dna'
			  },
			  -max_retry_count => 1,
			  -hive_capacity   => 10,
			  -priority        => 5,
			  -rc_name         => 'default',
		  },

		  {
			  -logic_name => 'dump_dna',
			  -module => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
			  -parameters => {
				  sequence_type_list  => $self->o('dna_sequence_type_list'),
				  process_logic_names => $self->o('process_logic_names'),
				  skip_logic_names    => $self->o('skip_logic_names'),
			  },
			  -can_be_empty    => 1,
			  -flow_into       => { 1 => 'concat_fasta' },
			  -max_retry_count => 1,
			  -hive_capacity   => 10,
			  -priority        => 5,
			  -rc_name         => 'default',
		  },

		  # Creating the 'toplevel' dumps for 'dna', 'dna_rm' & 'dna_sm'
		  {
			  -logic_name => 'concat_fasta',
			  -module =>
				'Bio::EnsEMBL::Production::Pipeline::FASTA::ConcatFiles',
			  -can_be_empty    => 1,
			  -max_retry_count => 5,
			  -priority        => 5,
			  -flow_into       => {
				  1 => [qw/primary_assembly/]
			  },
		  },

		  {
			  -logic_name => 'primary_assembly',
			  -module =>
'Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly',
			  -can_be_empty    => 1,
			  -max_retry_count => 5,
			  -priority        => 5,
			  -wait_for        => 'dump_dna'
		  }
	  ];
}

1;

