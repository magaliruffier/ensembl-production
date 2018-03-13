package Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandler;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Common::Base);

sub run {
    my ($self) = @_;
    my $token = $self->param_required('init_job_id');
    my $output = {"status":"success"};
    $self->dataflow_output_id(	   
			      {
			       job_id => $token,
			       output=>encode_json(
						   $output
						  )
			      }
			      , 2);
    
	return;
}
1;