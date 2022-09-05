
import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import ShardedWallet from "../contracts/ShardedWallet.cdc"

transaction(name: String) {

    let shardedVault: &ShardedWallet.Client
    let receiver: ShardedWallet.FungibleTokenReceiver

    prepare(signer: AuthAccount) {
        self.shardedVault = signer.borrow<&ShardedWallet.Client>(from: ShardedWallet.shardedWalletClientStoragePath)!

        self.receiver = ShardedWallet.FungibleTokenReceiver(
            name: "testFlow",
			receiver: signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver),
			accept: Type<@FlowToken.Vault>(),
			tags: ["flow"]
            )

    }

    execute {
        self.shardedVault.setReceiver(name: name, receivers: [self.receiver])
    }
}