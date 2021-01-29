// SharedWallet is a contract that enables a wallet that will wrap a FungibleToken.Vault and distribute ft according to the provieded fractions

import FungibleToken from 0xee82856bf20e2aa6

pub contract ShardedWallet {

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensDistributedTotal(amount: UFix64, from: Address?)
    pub event TokensDistributed(amount: UFix64, from: Address?,  to:Address?, toName: String)

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

    pub resource interface WalletOwner {

        pub fun getMembers() : {String: ShardedMember}  
        pub fun setMembers(_ members: {String: ShardedMember})
        pub fun distribute(_ amount: UFix64) 
        pub fun distributeAll() 
    }

    // Wallet
    //
    // A shared wallet wrapping another FungibleToken.Vault
    // When distributing money from the wallet it is distributed given the fractions for the members
    pub resource Wallet:FungibleToken.Receiver, WalletOwner{


        access(self) var vault: @FungibleToken.Vault
        access(self) var members: { String: ShardedMember}

        //initalize the Wallet with a wrapped vault and members
        init(vault: @FungibleToken.Vault, members: {String: ShardedMember}) {
            self.vault <- vault
            self.members=members
        }

        pub fun getMembers() : {String: ShardedMember} {
            return self.members
        }

        pub fun setMembers(_ members: {String: ShardedMember} ) {
            ShardedWallet.assertFractions(members)
            self.members=members
        }

        //does this make sense?
        pub fun createWalletOwner(_ account: AuthAccount): &{WalletOwner}? {

            for member in self.members.values {
                if member.receiver.borrow()!.owner?.address == account.address {
                    return &self as &{WalletOwner}
                }
            }
            return nil
        }

        // distribute
        //
        // Distribute the given amount according to the fractions of the members
        //
        pub fun distribute(_ amount: UFix64) {
            pre {
                self.vault.balance >= amount : "Not enough balance to distribute that amount"
            }

            for member in self.members.keys {
              let shardedMember= self.members[member]!
              let shardedAmount= amount* shardedMember.fraction
              let receiver =shardedMember.receiver.borrow()!
              receiver.deposit(from: <- self.vault.withdraw(amount: shardedAmount))
              emit TokensDistributed(amount:shardedAmount, from:self.owner?.address, to:receiver.owner?.address, toName: member)
            } 
            emit TokensDistributedTotal(amount: amount, from: self.owner?.address)
        }


        pub fun distributeAll() {
            self.distribute(self.vault.balance)
        }

        // deposit
        //
        // delegate the deposit to the wrapped vault 
         pub fun deposit(from: @FungibleToken.Vault) {
            self.vault.deposit(from: <- from)
        }

        destroy() {
            self.distributeAll()
            destroy self.vault
        }
    }

    pub fun assertFractions(_ members: {String:ShardedMember}) {
         var total:UFix64=0.0
        for member in members.keys {
            let shardedMember= members[member]!
            total = total+shardedMember.fraction
        }
        if total !=1.0 {
            panic("Cannot create vault without fully distributing the rewards")
        }
    }
    // createWallet
    //
    // Function that creates a sharded wallet wrapping a given vault and with members with a given fraction.
    // The string key of the members array are for inrmation purposes only
    //
    pub fun createWallet(vault: @FungibleToken.Vault,members: {String:ShardedMember}): @ShardedWallet.Wallet {
        self.assertFractions(members)
        return <-create Wallet(vault: <- vault, members: members)
    }

}
   

   
