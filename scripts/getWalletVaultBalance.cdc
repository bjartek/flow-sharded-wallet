import ShardedWallet from "../contracts/ShardedWallet.cdc"

pub fun main(addr: Address) : {String : UFix64} {
    let ref = getAuthAccount(addr).borrow<&ShardedWallet.Wallet>(from: ShardedWallet.shardedWalletStoragePath)!

    let res : {String : UFix64} = {}
    let data = ref.getVaultBalances()
    for key in data.keys {
        res[key.identifier] = data[key]!
    }
    return res
}