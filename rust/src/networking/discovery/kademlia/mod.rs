use {
  alloy_primitives::{B256, B512, keccak256},
  alloy_rlp::{RlpDecodable, RlpEncodable},
  ethereum_types::U256,
  std::net::IpAddr,
};

pub const BUCKET_COUNT: usize = 256;

pub struct Kademlia {
  localNodeID: B512,
  buckets: Vec<Bucket>,
}

impl Kademlia {
  pub fn new(localNodeID: B512) -> Self {
    Self {
      localNodeID,
      buckets: Vec::new(),
    }
  }

  pub fn insert_node(&mut self, node: Node) -> (Option<Peer>, bool) {
    unimplemented!()
  }
}

/*
  The public key of the node represents the node ID.
  The distance between two nodes is the bitwise exclusive or (XOR) on the hashes of the public
  keys, taken as the number.

    distance(n₁, n₂) = keccak256(n₁) XOR keccak256(n₂)
*/
// calculateDistance calculates the distance between 2 nodes having the corresponding public keys.
pub fn calculate_distance(node_a_id: B512, node_b_id: B512) -> usize {
  let node_a_hash: B256 = keccak256(node_a_id);
  let node_b_hash: B256 = keccak256(node_b_id);

  let distance = node_a_hash ^ node_b_hash;

  let distance = U256::from_big_endian(&distance.0).bits();
  return distance;
}

pub struct Bucket {}

pub struct Peer {
  pub node: Node,

  pub lastPing: u64,
  pub lastPingHash: Option<B256>,

  pub lastPong: u64,
}

#[derive(Debug, RlpEncodable, RlpDecodable)]
pub struct Node {
  pub ipAddress: IpAddr,

  pub udpPort: u16,
  pub tcpPort: u16,

  pub nodeID: B512,
}

impl Node {
  pub fn enode(&self) -> String {
    let encodedNodeID = hex::encode(self.nodeID);

    format!(
      "enode://{}@{}:{}?discport={}",
      encodedNodeID, self.ipAddress, self.tcpPort, self.udpPort
    )
  }
}
