import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"

transaction(receiver: Address, amount: UFix64) {

    let signerVault: &FungibleToken.Vault

    let shardedVault: &{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        self.signerVault = signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)!

        self.shardedVault = getAccount(receiver).getCapability(ShardedWallet.shardedWalletReceiverPath)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Unable to borrow receiver reference")
    }

    execute {
        self.shardedVault.deposit(from: <- self.signerVault.withdraw(amount: amount))
    }
}