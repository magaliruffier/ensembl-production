package Bio::EnsEMBL::Production::Pipeline::EventHandling::EventHandler;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Common::Base);

sub run {
    my ($self) = @_;
    # read event from input
    my $event = $self->param_required('event');
    my $genome = $event->{genome};
    $self->log()->info("Generating job for species $genome");
    $self->dataflow_output_id({species => $genome}, 2);
    # main semaphore flow to 1 with original input
    $self->dataflow_output_id(
			      {
			       init_job_id=>$self->input_job()->dbID(),
			       event=>$event
			      },
			      1
    );
    return;
}
1;
