// DemoToken is a fungible token used for testing marketplace purchases

// This has been left really really simple since we expect the Flow token will replace this.

// Import the Flow FungibleToken interface
import FungibleToken from 0xee82856bf20e2aa6
import DemoToken from 0x01cf0e2f2f715450

pub contract ShardedWallet {

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensShared(amount: UFix64, from: Address?,  to:Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)


    pub struct ShardedMember {
        pub let receiver:Capability<&{FungibleToken.Receiver}> 
        pub let fraction: UFix64

        init( receiver: Capability<&{FungibleToken.Receiver}>, fraction: UFix64) {
            self.receiver=receiver
            self.fraction=fraction
        }
    }

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault:FungibleToken.Receiver{

        // holds the balance of a users tokens
        pub var balance: UFix64

        pub var members: { Address: ShardedMember}
        // initialize the balance at resource creation time
        init(balance: UFix64, members: {Address: ShardedMember}) {
            self.balance = balance
            self.members=members
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UFix64) {
            self.balance = self.balance - amount
            for member in self.members.keys {
              let shardedMember= self.members[member]!
              let shardedAmount= amount* shardedMember.fraction
              let receiver =shardedMember.receiver.borrow()!
              receiver.deposit(from: <- DemoToken.createVaultWithTokens(shardedAmount))
              emit TokensShared(amount:shardedAmount, from:self.owner?.address, to:receiver.owner?.address)
            } 
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @FungibleToken.Vault) {
            self.balance = self.balance + from.balance
            emit TokensDeposited(amount: from.balance, to: self.owner?.address)
            destroy from
        }

    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(members: {Address:ShardedMember}): @ShardedWallet.Vault {
        var total:UFix64=0.0
        for member in members.keys {
            let shardedMember= members[member]!
            total = total+shardedMember.fraction
        }
        if total !=1.0 {
            panic("Cannot create vault without fully distributing the rewards")
        }
        return <-create Vault(balance: 0.0, members: members)
    }

}
   

   
