// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the exampleToken

import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"

transaction(memberNames: [String], memberAddresses: [Address], memberCuts: [UFix64]) {

    prepare(signer: AuthAccount) {

        if memberNames.length != memberNames.length || memberNames.length != memberCuts.length {
            panic("The lengthes of arrays passed in are not equal")
        }

       //send in the wallet client
        let shardedMembers : {Address:ShardedWallet.ShardedMember} = {} 
        for i, name in memberNames {
            shardedMembers[memberAddresses[i]] = ShardedWallet.ShardedMember(
                name: name, 
                owner:memberAddresses[i], 
                receivers:[
                        ShardedWallet.FungibleTokenReceiver(
                            name: "flow",
                            receiver: getAccount(memberAddresses[i]).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                            accept: Type<@FlowToken.Vault>(),
                            tags: ["flow", "flowToken"]
                        )
                ], 
                fraction: memberCuts[i]
            )
        }

        // Create a new ShardedWallet Vault and put it in storage
        signer.save(
            <-ShardedWallet.createWallet(members: shardedMembers),
            to: ShardedWallet.shardedWalletStoragePath
        )

        signer.link<&ShardedWallet.Wallet>(ShardedWallet.shardedWalletPrivatePath, target:ShardedWallet.shardedWalletStoragePath)


        //note that this capability is in _private_ not in public. This is what makes this safe
        let walletCapability = signer.getCapability<&ShardedWallet.Wallet>(ShardedWallet.shardedWalletPrivatePath)

        //TODO should this be done in the contract or in the transaction?
        //TODO if a member has not created this client it should be ok? 

        for i , name in memberNames{
            let memberClient= getAccount(memberAddresses[i]).getCapability<&{ShardedWallet.ClientPublic}>(ShardedWallet.shardedWalletClientPublicPath)
            memberClient.borrow()!.addServer(name: name, cap: walletCapability)
        }

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        signer.link<&ShardedWallet.Wallet{FungibleToken.Receiver}>(
            ShardedWallet.shardedWalletReceiverPath,
            target: ShardedWallet.shardedWalletStoragePath
        )

    }
}