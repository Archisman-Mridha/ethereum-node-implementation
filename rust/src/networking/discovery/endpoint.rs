use {
  alloy_rlp::{RlpDecodable, RlpEncodable},
  std::net::IpAddr,
};

#[derive(Debug, RlpEncodable, RlpDecodable)]
pub struct Endpoint {
  pub ipAddress: IpAddr,

  pub udpPort: u16,
  pub tcpPort: u16,
}
