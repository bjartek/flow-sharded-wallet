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

  


    // Wallet
    //
    // A shared wallet wrapping another FungibleToken.Vault
    // When distributing money from the wallet it is distributed given the fractions for the members
    pub resource Wallet:FungibleToken.Receiver{


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
            ShardedWallet.assertMembers(members)
            self.members=members
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

    pub fun assertMembers(_ members: {String:ShardedMember}) {
         var total:UFix64=0.0
        for member in members.keys {
            let shardedMember= members[member]!
            if !shardedMember.receiver.check()  {
                panic("Receiver needs to exist for member ".concat(member))
            }
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
        self.assertMembers(members)
        return <-create Wallet(vault: <- vault, members: members)
    }

  // implementing https://docs.onflow.org/cadence/design-patterns#capability-receiver
  // this allows other accounts to call the methods in the Client
  pub resource interface ClientPublic {
        pub fun addCapability(cap: Capability<&Wallet>) 
    }

    pub resource Client:ClientPublic {

        access(self) var addAccountCapability: Capability<&Wallet>?

        init() {
            self.addAccountCapability = nil
        }

        pub fun addCapability(cap: Capability<&Wallet>) {
            pre {
                cap.check() : "Invalid wallet capablity"
            }
            self.addAccountCapability = cap
        }

        pub fun distributeAll() {
            pre {
                self.addAccountCapability != nil: 
                    "Cannot distribute until registration is complete"
            }
            let walletRef = self.addAccountCapability!.borrow()!
            walletRef.distributeAll()
        }

        pub fun distribute(_ amount: UFix64) {
           pre {
                self.addAccountCapability != nil: 
                    "Cannot distribute until registration is complete"
            }
            let walletRef = self.addAccountCapability!.borrow()!
            walletRef.distribute(amount)
        }
    }

    pub fun createClient(): @ShardedWallet.Client {
        return <- create Client()
    }
}
   

   
