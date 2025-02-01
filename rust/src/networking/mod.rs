pub mod bootnode;
pub mod discovery;

/*
  Ethereum is a peer-to-peer network with thousands of nodes that must be able to communicate
  with one another using standardized protocols.

  There are two parts to the client software (execution clients and consensus clients), each with
  its own distinct networking stack.

  The execution layer's networking protocols is divided into two stacks : the Discovery stack
  and the DevP2P stack.
*/
pub struct NetworkingStack {}
