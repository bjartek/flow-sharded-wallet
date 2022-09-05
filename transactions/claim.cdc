
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction(name: String, type: String, amount: UFix64) {

    let shardedVault: &ShardedWallet.Client

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: ShardedWallet.shardedWalletClientStoragePath)!
    }

    execute {
        self.shardedVault.claimByWalletType(name: name, type: CompositeType(type)!, amount: amount)
    }
}