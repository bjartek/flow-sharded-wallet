// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the exampleToken

import FungibleToken from 0xee82856bf20e2aa6
import ShardedWallet, DemoToken from 0x01cf0e2f2f715450

transaction(memberAddress: Address) {

    prepare(signer: AuthAccount) {

        let member = getAccount(memberAddress)

        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&ShardedWallet.Wallet>(from: /storage/ShardedWallet) != nil {
            return
        }

        let signerRef = signer.getCapability<&{FungibleToken.Receiver}>(/public/DemoTokenReceiver)
        if !signerRef.check() {
            panic("Needs a valid FungibleToken.Receiver linked")
        }
        let memberRef = member.getCapability<&{FungibleToken.Receiver}>(/public/DemoTokenReceiver)
        if !memberRef.check() {
            panic("Needs a valid FungibleToken.Receiver linked")
        }


       
       //send in the wallet client
        let members = { 
            "user1": ShardedWallet.ShardedMember(receiver:signerRef, fraction: UFix64(0.5)), 
            "user2": ShardedWallet.ShardedMember(receiver: memberRef, fraction: UFix64(0.5))
        }
        //Create a sharded wallet split 50/50, only 
        // Create a new ShardedWallet Vault and put it in storage
        signer.save(
            <-ShardedWallet.createWallet(vault: <- DemoToken.createEmptyVault(), members: members),
            to: /storage/ShardedWallet
        )

        signer.link<&ShardedWallet.Wallet>(/private/SharedWallet, target:/storage/ShardedWallet)


        //note that this capability is in _private_ not in public. This is what makes this safe
        let walletCapability = signer.getCapability<&ShardedWallet.Wallet>(/private/SharedWallet)

        //TODO should this be done in the contract or in the transaction?
        //TODO if a member has not created this client it should be ok? 
        let signerClient= signer.getCapability<&{ShardedWallet.ClientPublic}>(/public/ShardedWalletClient)
        let memberClient= member.getCapability<&{ShardedWallet.ClientPublic}>(/public/ShardedWalletClient)
        signerClient.borrow()!.addCapability(cap: walletCapability)
        memberClient.borrow()!.addCapability(cap: walletCapability)


        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        signer.link<&ShardedWallet.Wallet{FungibleToken.Receiver}>(
            /public/ShardedWalletReceiver,
            target: /storage/ShardedWallet
        )

    }
}