// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the exampleToken

import FungibleToken from 0xee82856bf20e2aa6
import DemoToken, ShardedWallet from 0x01cf0e2f2f715450

transaction {

    prepare(signer: AuthAccount) {

        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&FungibleToken.Vault>(from: /storage/DemoTokenVault) != nil {
            return
        }

        //create a new ShardedWallet client since we want to be able to distribute from the ShardedWallet
        let userWalletClient <- ShardedWallet.createClient()
        signer.save<@ShardedWallet.Client>(<- userWalletClient, to:/storage/ShardedWalletClient)
        signer.link<&{ShardedWallet.ClientPublic}>( /public/ShardedWalletClient, target: /storage/ShardedWalletClient)


           // create a new empty Vault resource for signer
        let signerVault <- DemoToken.createVaultWithTokens(100.0)
        signer.save<@FungibleToken.Vault>(<-signerVault, to: /storage/DemoTokenVault)
        signer.link<&{FungibleToken.Receiver}>( /public/DemoTokenReceiver, target: /storage/DemoTokenVault)
        signer.link<&{FungibleToken.Balance}>( /public/DemoTokenBalance, target: /storage/DemoTokenVault)

        //create a wallet client and link it
    }
}