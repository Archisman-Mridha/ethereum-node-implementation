use {
  super::endpoint::Endpoint,
  alloy_primitives::B256,
  alloy_rlp::{Decodable, Encodable, Header, RlpDecodable, RlpEncodable},
};

#[derive(Debug, RlpEncodable, RlpDecodable)]
pub struct Packet {
  pub header: PacketHeader,
  pub data: PacketData,
}

#[derive(Debug, RlpEncodable, RlpDecodable)]
pub struct PacketHeader {
  // Exists to make the packet format recognizable when running multiple protocols on the same
  // UDP port. It serves no other purpose.
  // This is the Keccak256 hash of the packet content.
  pub hash: B256,

  // Packet data of every packet is signed by the node's identity key.
  // This represents that ECDSA signature.
  pub signature: H520,

  // Defines the type of the packet / message.
  pub r#type: u8,
}

#[derive(Debug)]
pub enum PacketData {
  Ping(PingPacketData),
  Pong(PongPacketData),
}

impl Encodable for PacketData {
  fn encode(&self, out: &mut dyn alloy_rlp::BufMut) {
    match self {
      PacketData::Ping(pingPacketData) => pingPacketData.encode(out),
      PacketData::Pong(pongPacketData) => pongPacketData.encode(out),
    }
  }
}

impl Decodable for PacketData {
  fn decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
    let packetType = u8::decode(&mut Header::decode_bytes(buf, true)?)?;
    let packetData = match packetType {
      1 => Self::Ping(PingPacketData::decode(buf)?),
      2 => Self::Pong(PongPacketData::decode(buf)?),

      _ => return Err(alloy_rlp::Error::Custom("Unknown packet type")),
    };
    Ok(packetData)
  }
}

/*
  When a Ping type packet is received, the recipient should reply with a Pong type packet. It may
  also consider the sender for addition into the local table.

  If no communication with the sender has occurred within the last 12h, a ping should be sent in
  addition to pong in order to receive an endpoint proof.

  Packets that mismatch the discovery protocol version we're using, will be ignored.
*/
#[derive(Debug, RlpEncodable, RlpDecodable)]
#[rlp(trailing)]
pub struct PingPacketData {
  // The Discovery protocol version the message sender is using.
  // Must be set to 4.
  pub version: u8,

  pub from: Endpoint,
  pub to: Endpoint,

  // An absolute UNIX time stamp.
  // Expired packets will not be processed.
  pub expiration: u64,

  // ENR sequence number of the sender.
  pub enrSequenceNumber: Option<u64>,
}

// Pong type packet is the reply to a Ping type packet.
// We will ignore unsolicited Pong type packets that do not contain the hash of the most recent
// corresponding Ping type packet (if it was sent).
#[derive(Debug, RlpEncodable, RlpDecodable)]
#[rlp(trailing)]
pub struct PongPacketData {
  // Hash of the corresponding Ping type packet.
  pub pingHash: Endpoint,

  // An absolute UNIX time stamp.
  // Expired packets will not be processed.
  pub expiration: u64,

  // ENR sequence number of the sender.
  pub enrSequenceNumber: Option<u64>,
}
