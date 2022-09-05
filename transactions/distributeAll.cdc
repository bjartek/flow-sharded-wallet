
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction() {

    let shardedVault: &ShardedWallet.Wallet

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Wallet>(from: ShardedWallet.shardedWalletStoragePath)!
    }

    execute {
        self.shardedVault.distributeAll()
    }
}
