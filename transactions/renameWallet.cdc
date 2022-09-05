
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction(name: String, newName: String) {

    let shardedVault: &ShardedWallet.Client

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: ShardedWallet.shardedWalletClientStoragePath)!
    }

    execute {
        self.shardedVault.renameWallet(oldName: name, newName: newName)
    }
}