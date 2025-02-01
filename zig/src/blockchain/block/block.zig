// Blocks are batches of transactions with a hash of the previous block in the chain.
//
// This links blocks together (in a chain) because hashes are cryptographically derived from the
// block data. This prevents fraud, because one change in any block in history would invalidate all
// the following blocks as all subsequent hashes would change and everyone running the blockchain
// would notice.
//
// Batching transactions into blocks means dozens (or hundreds) of transactions are committed,
// agreed on, and synchronized all at once.
// By spacing out commits, we give all network participants enough time to come to consensus: even
// though transaction requests occur dozens of times per second, blocks are only created and
// committed on Ethereum once every twelve seconds.
pub const Block = struct {};
