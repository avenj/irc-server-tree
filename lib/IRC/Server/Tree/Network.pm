package IRC::Server::Tree::Network;

## An IRC Network with route memoization and simple sanity checks
## IRC::Server::Tree lives in ->tree()

use strictures 1;

use Carp;
use Scalar::Util 'blessed';

use IRC::Server::Tree;

sub new {
  my $class = shift;
  my $self = {
    tree => (
        ref $_[0] && $_[0]->isa('IRC::Server::Tree') ?
          $_[0] : IRC::Server::Tree->new
      ),

    ## Track unique names and routes in ->{seen}
    seen   => {},
  };

  bless $self, $class;

  my $all_names = $self->tree->names_beneath( $self->tree );
  for my $name (@$all_names) {
    if (++$self->{seen}->{$name} > 1) {
      croak "Passed a broken Tree; duplicate node entries for $name"
    }
  }

  $self
}

sub tree {
  my ($self) = @_;
  $self->{tree}
}

sub have_peer {
  my ($self, $peer) = @_;

  return 1 if $self->{seen}->{$peer};

  return
}

sub _have_route_for_peer {
  my ($self, $peer) = @_;

  if (ref $self->{seen}->{$peer} eq 'ARRAY') {
    return $self->{seen}->{$peer}
  }

  return
}

sub add_peer_to_self {
  my ($self, $peer, $arrayref) = @_;

  confess "add_peer_to_self expects a peer name"
    unless defined $peer;

  if ( $self->have_peer($peer) ) {
    carp "Tried to add previously-seen node $peer";
    return
  }

  $self->tree->add_node_to_top($peer, $arrayref);
  $self->{seen}->{$peer} = 1;
}

sub add_peer_to_name {
  my ($self, $parent_name, $new_name, $arrayref) = @_;

  ## FIXME
  ## Hmm.. currently no convenient way to use memoized routes
  ## when adding.
  ## Probably should have an add in Tree that can take numerical
  ## routes to the parent's ref.

  if ( $self->have_peer($new_name) ) {
    carp "Tried to add previously-seen node $new_name";
    return
  }

  $self->tree->add_node_to_name($parent_name, $new_name, $arrayref);
  $self->{seen}->{$new_name} = 1;
}

sub split_peer {
  ## Split a peer and return the names of all hops under it.
  my ($self, $peer) = @_;

  my $splitref = $self->tree->del_node_by_name( $peer ) || return;

  delete $self->{seen}->{$peer};

  my $names = $self->tree->names_beneath( $splitref );

  wantarray ? @$names : $names
}

sub hop_count {
  ## Returns a hop count as normally used in LINKS output and similar
  my ($self, $peer_name) = @_;

  my $path = $self->trace( $peer_name );
  return unless $path;

  scalar(@$path)
}

sub trace {
  my ($self, $peer) = @_;

  if (my $routed = $self->_have_route_for_peer($peer) ) {
    return $routed
  }

  my $traced = $self->tree->trace( $peer );

  return unless ref $traced eq 'ARRAY';

  $self->{seen}->{$peer} = $traced;

  $traced
}


1;

=pod

=head1 NAME

IRC::Server::Tree::Network - An enhanced IRC::Server::Tree

=head1 SYNOPSIS

  ## Model a network
  my $net = IRC::Server::Tree::Network->new;

  ## Add a couple top-level peers
  $net->add_peer_to_self('hubA');
  $net->add_peer_to_self('leafA');

  ## Add some peers to hubA
  $net->add_peer_to_name('hubA', 'leafB');
  $net->add_peer_to_name('hubA', 'leafC');

  ## [ 'leafB', 'leafC' ] :
  my $split = $net->split_peer('hubA');

See below for complete details.

=head1 DESCRIPTION

An IRC::Server::Tree::Network provides simpler methods for interacting 
with an L<IRC::Server::Tree>. It also handles L</trace> route memoization 
and uniqueness-checking.

=head2 new

  my $net = IRC::Server::Tree::Network->new;
  my $net = IRC::Server::Tree::Network->new(
    IRC::Server::Tree->new( $previous_tree )
  );

The constructor initializes a fresh Network.

If an existing Tree is passed in, a list of unique node names in the Tree 
is compiled and validated.

Routes are not stored until a L</trace> is called.

=head2 add_peer_to_self

  $net->add_peer_to_self( $peer_name );

Adds a node identified by the specified peer name to the top level of our 
tree; i.e., a directly-linked peer.

The identifier must be unique. IRC networks may not have duplicate 
entries in the tree.

=head2 add_peer_to_name

  $net->add_peer_to_name( $parent_name, $new_peer_name );

Add a node identified by the specified C<$new_peer_name> to the specified 
C<$parent_name>.

Returns empty list and warns if the specified parent is not found.

=head2 have_peer

  if ( $net->have_peer( $peer_name ) ) {
    . . .
  }

Returns a boolean value indicating whether or not the specified name is 
unique.

=head2 hop_count

  my $count = $net->hop_count;

Returns the number of hops to the destination node; i.e., a 
directly-linked peer is 1 hop away:

  hubA
    leafA     - 1 hop
    hubB      - 1 hop
      leafB   - 2 hops

=head2 split_peer

  my $split_names = $net->split_peer( $peer_name );

Splits a node from the tree.

Returns an ARRAY containing the names of every node beneath the one that 
was split, not including the originally specified peer.

=head2 trace

  my $trace_names = $net->trace( $peer_name );

Returns the same value as L<IRC::Server::Tree/trace>; see the 
documentation for L<IRC::Server::Tree> for details.

This proxy method memoizes routes for future lookups. They are cleared 
when L</split_peer> is called.

=head2 tree

The C<tree()> method returns the L<IRC::Server::Tree> object belonging to 
this Network.

  my $as_hash = $net->tree->as_hash;

See the L<IRC::Server::Tree> documentation for details.

Note that calling methods on the Tree object that manipulate the tree 
(adding and deleting nodes) will break future lookups via Network. Don't 
do that; if you need to manipulate the Tree directly, fetch it, change 
it, and create a new Network:

  my $tree = $net->tree;

  ## ... call methods on the IRC::Server::Tree ...
  $tree->del_node_by_name('SomeNode');

  my $new_net = IRC::Server::Tree::Network->new(
    $tree
  );

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
