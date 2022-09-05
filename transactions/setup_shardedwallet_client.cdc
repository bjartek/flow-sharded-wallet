// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the exampleToken

import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction {

    prepare(signer: AuthAccount) {
        //create a new ShardedWallet client since we want to be able to distribute from the ShardedWallet
        let userWalletClient <- ShardedWallet.createClient()
        signer.save<@ShardedWallet.Client>(<- userWalletClient, to:ShardedWallet.shardedWalletClientStoragePath)
        signer.link<&ShardedWallet.Client{ShardedWallet.ClientPublic}>( ShardedWallet.shardedWalletClientPublicPath, target: ShardedWallet.shardedWalletClientStoragePath)
    }
}