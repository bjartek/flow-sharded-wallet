// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the exampleToken

import FungibleToken from 0xee82856bf20e2aa6
import ShardedWallet from 0x01cf0e2f2f715450

transaction(memberAddress: Address) {

    prepare(signer: AuthAccount) {

        let member = getAccount(memberAddress)

        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&ShardedWallet.Vault>(from: /storage/ShardedWalletTokenVault) != nil {
            return
        }

        let signerRef = signer.getCapability<&{FungibleToken.Receiver}>(/public/DemoTokenReceiver)
        let memberRef = member.getCapability<&{FungibleToken.Receiver}>(/public/DemoTokenReceiver)

        let members= { 
            signer.address: ShardedWallet.ShardedMember(receiver:signerRef, fraction: UFix64(0.5)), 
            member.address: ShardedWallet.ShardedMember(receiver: memberRef, fraction: UFix64(0.5))
           
        }
        //Create a sharded wallet split 50/50, only 
        // Create a new ShardedWallet Vault and put it in storage
        signer.save(
            <-ShardedWallet.createEmptyVault(members: members),
            to: /storage/ShardedWalletTokenVault
        )

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        signer.link<&ShardedWallet.Vault{FungibleToken.Receiver}>(
            /public/ShardedWalletReceiver,
            target: /storage/ShardedWalletTokenVault
        )

    }
}