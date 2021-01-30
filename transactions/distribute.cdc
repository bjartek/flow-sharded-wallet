
import FungibleToken from 0xee82856bf20e2aa6
import ShardedWallet from 0x01cf0e2f2f715450

// This transaction can be signed by any of the users that are in the ShardedWallet
// any of them can distribute tokens 
transaction(amount: UFix64) {

    let shardedVault: &ShardedWallet.Client

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: /storage/ShardedWalletClient)!
    }

    execute {
        self.shardedVault.distribute(amount)
    }
}