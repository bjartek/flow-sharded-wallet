import ShardedWallet from "../contracts/ShardedWallet.cdc"

pub fun main(addr: Address) : {String : ShardedWallet.ShardedMember} {
    let ref = getAccount(addr).getCapability<&ShardedWallet.Client{ShardedWallet.ClientPublic}>(ShardedWallet.shardedWalletClientPublicPath).borrow()!
    return ref.getAllWallets()
} 