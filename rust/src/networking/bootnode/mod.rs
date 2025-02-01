use {alloy_primitives::B512, std::net::SocketAddr};

pub struct BootNode {
  pub nodeID: B512,
  pub socketAddress: SocketAddr,
}
