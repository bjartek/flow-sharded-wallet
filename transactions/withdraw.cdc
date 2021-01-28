
import FungibleToken from 0xee82856bf20e2aa6
import ShardedWallet, DemoToken from 0x01cf0e2f2f715450

transaction(amount: UFix64) {

    let shardedVault: &ShardedWallet.Vault

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Vault>(from: /storage/ShardedWalletTokenVault)!
    }

    execute {
        self.shardedVault.withdraw(amount: amount)
    }
}