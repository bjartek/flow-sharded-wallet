
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction(name: String) {

    let shardedVault: &ShardedWallet.Client

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: ShardedWallet.shardedWalletClientStoragePath)!
    }

    execute {
        self.shardedVault.claimAllInWallet(name: name)
    }
}