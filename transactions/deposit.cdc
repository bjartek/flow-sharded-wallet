import FungibleToken from 0xee82856bf20e2aa6
import ShardedWallet from 0x01cf0e2f2f715450
import FlowToken from 0x0ae53cb6e3f42a79

transaction(amount: UFix64) {

    let signerVault: &FungibleToken.Vault

    let shardedVault: &{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        self.signerVault = signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)!

        self.shardedVault = signer.getCapability(/public/ShardedWalletReceiver)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Unable to borrow receiver reference")
    }

    execute {
        self.shardedVault.deposit(from: <- self.signerVault.withdraw(amount: amount))
    }
}