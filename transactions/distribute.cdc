
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

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