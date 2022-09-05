
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction() {

    let shardedVault: &ShardedWallet.Client

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: ShardedWallet.shardedWalletClientStoragePath)!
    }

    execute {
        for wallet in self.shardedVault.getAllWallets().keys {
            self.shardedVault.claimAllInWallet(name: wallet)
        }
    }
}
 