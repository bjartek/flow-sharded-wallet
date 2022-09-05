
import FlowToken from "../contracts/standard/FlowToken.cdc"
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction(memberNames: [String], memberAddresses: [Address], memberCuts: [UFix64]) {

    let shardedVault: &ShardedWallet.Wallet

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Wallet>(from: ShardedWallet.shardedWalletStoragePath)!
    }

    execute {

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

        self.shardedVault.setMembers(shardedMembers)
    }
}