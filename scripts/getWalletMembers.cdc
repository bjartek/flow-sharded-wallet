import ShardedWallet from "../contracts/ShardedWallet.cdc"

pub fun main(addr: Address) : {Address : ShardedWallet.ShardedMember} {
    let ref = getAuthAccount(addr).borrow<&ShardedWallet.Wallet>(from: ShardedWallet.shardedWalletStoragePath)!
    return ref.getMembers()
}