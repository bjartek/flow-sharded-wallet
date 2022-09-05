// SharedWallet is a contract that enables a wallet that will wrap a FungibleToken.Vault and distribute ft according to the provieded fractions

import FungibleToken from "./standard/FungibleToken.cdc"

pub contract ShardedWallet {

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensDistributedTotal(amount: UFix64, type: String)
    pub event TokensDistributed(amount: UFix64, to:Address?, toName: String, type: String)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDepositedToShardedWallet(amount: UFix64, walletAddress: Address, to: Address?, type: String)
    pub event TokensDepositedToShardedWalletTotal(amount: UFix64, walletAddress: Address, type: String)

    // Event that token cannot be distributed
    pub event TokensFailedToDistribute(amount: UFix64, to: Address?, type: String)

    pub let shardedWalletStoragePath : StoragePath 
    pub let shardedWalletPrivatePath : PrivatePath 
    pub let shardedWalletReceiverPath : PublicPath 
    pub let shardedWalletClientStoragePath : StoragePath 
    pub let shardedWalletClientPrivatePath : PrivatePath 
    pub let shardedWalletClientPublicPath : PublicPath 

    pub struct interface Receiver {
        pub fun getReceiverCap() : Capability<&{FungibleToken.Receiver}>
        pub fun getAcceptTypes() : [Type]
        pub fun checkReceiver(_ type: Type) : Bool 
        pub fun deposit(from: @FungibleToken.Vault)

        // get the type of the receiver, e.g. FT.Vaults or Profile.User
        pub fun getReceiverType() : Type
    }

    // This is copied from Profile, but modified a little to suit the use of Sharded Wallet
    pub struct FungibleTokenReceiver : Receiver {
		pub let name: String
		pub let receiver: Capability<&{FungibleToken.Receiver}>
		pub let accept: Type
		pub let tags: [String]
        pub let receiverType: Type

		init(
			name: String,
			receiver: Capability<&{FungibleToken.Receiver}>,
			accept: Type,
			tags: [String]
		) {
			self.name=name
			self.receiver=receiver
			self.accept=accept
			self.tags=tags
            self.receiverType=receiver.borrow()!.getType()
		}

        pub fun getReceiverType() : Type {
            return self.receiverType
        }

        pub fun getReceiverCap() : Capability<&{FungibleToken.Receiver}> {
            return self.receiver
        }

        pub fun getAcceptTypes() : [Type] {
            return [self.accept]
        }

        pub fun checkReceiver(_ type: Type) : Bool {
            if self.accept == type {
                return self.receiver.check()
            }
            return false
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            if !self.receiver.check() {
                panic("Receiver capability is no longer valid. ReceiverName : ".concat(self.name))
            }
            self.receiver.borrow()!.deposit(from: <- from)
        }
	}

    pub struct ShardedMember {
        pub let name: String
        pub let owner: Address
        pub let receivers: {Type : {Receiver}}
        pub let fraction: UFix64
        pub let claimable: {Type : UFix64}
        pub var distribute: Bool

        // This is here to save gas. Every deposit will query if there's already a cache for receiver type here. If not, set it.
        // e.g. {FINDToken.Vault : Profile.User}
        pub let receiverCache: {Type : Type}

        init(name: String, owner: Address, receivers:[{Receiver}], fraction: UFix64) {
            self.name=name
            self.owner=owner
            let receiverMap : {Type : {Receiver}} = {}
            for receiver in receivers {
                receiverMap[receiver.getReceiverType()] = receiver
            }
            self.receivers=receiverMap
            self.fraction=fraction

            // auto distribute default to be false
            self.distribute=false
            self.claimable={}
            self.receiverCache={}
        }

        // If deposit fails, it will not panic, but return the vault with balance. 
        // Otherwise it will return with empty vault. 
        access(contract) fun deposit(from: @FungibleToken.Vault) : @FungibleToken.Vault {
            let type = from.getType()
            let balance = from.balance
            
            // If cache type is valid
            if let receiverType = self.receiverCache[type] {
                let receiver = self.receivers[receiverType]!
                if receiver.checkReceiver(type) {
                    // assert claimable and tidy up claimable
                    self.claimed(type: type, amount: balance)
                    let emptyVault <- from.withdraw(amount: 0.0)
                    receiver.deposit(from: <-from)
                    return <- emptyVault
                }
            }

            // If cache does not exist / is not valid
            for receiverType in self.receivers.keys {
                if self.receivers[receiverType]!.checkReceiver(type) {
                    // assert claimable and tidy up claimable
                    self.claimed(type: type, amount: balance)
                    let emptyVault <- from.withdraw(amount: 0.0)
                    self.receivers[receiverType]!.deposit(from: <-from)
                    // store the mapping of the vault type to the receiver type to save gas next time 
                    self.receiverCache[type] = receiverType
                    return  <- emptyVault
                }
            }

            // Ben : Should return the vault if failed to deposit
            //panic("No valid Receiver for this type. Type : ".concat(type.identifier))
            // emit TokensFailedToDistribute(amount: from.balance, to: self.owner, type: from.getType().identifier)
            return <- from
        }

        access(self) fun claimed(type: Type, amount: UFix64) {
            if self.claimable[type] == nil {
                panic("Portion for type : ".concat(type.identifier).concat(" is 0.0"))
            }

            if self.claimable[type]! < amount {
                panic(self.name.concat(" is claiming more than you are entitled. Entitled : ").concat((self.claimable[type] ?? 0.0).toString()).concat(" Claiming : ").concat(amount.toString()))
            }

            self.claimable[type] = self.claimable[type]! - amount 

            if self.claimable[type]! == 0.0 {
                self.claimable.remove(key: type) 
            }
        }

        access(contract) fun addContribution(type: Type, amount: UFix64) {
            let oldBalance = self.claimable[type] ?? 0.0
            self.claimable[type] = oldBalance + amount
        }

        access(contract) fun setReceiver(_ receivers: [{Receiver}]) {
            for receiver in receivers {
                // check if the receiver is valid
                for type in receiver.getAcceptTypes(){
                    if !receiver.checkReceiver(type) {
                        panic("Receiver with type ".concat(receiver.getReceiverCap().getType().identifier).concat(" is not valid"))
                    }
                }
                // If the receiver type already exist, replace that, otherwise add that. 
                self.receivers[receiver.getReceiverType()] = receiver
            }
        }

        access(contract) fun enableAutoDistribution(_ enable: Bool) {
            self.distribute = enable
        }

    }

    // Wallet
    //
    // A shared wallet wrapping another FungibleToken.Vault
    // When distributing money from the wallet it is distributed given the fractions for the members
    pub resource Wallet : FungibleToken.Receiver {

        access(self) var vaults: @{Type : FungibleToken.Vault}
        access(self) var members: {Address: ShardedMember}

        //initalize the Wallet with a wrapped vault and members
        init(members: {Address: ShardedMember}) {
            self.vaults <- {}
            self.members=members
        }

        access(self) fun borrowVault(_ type : Type) : &FungibleToken.Vault {
            return (&self.vaults[type] as &FungibleToken.Vault?)!
        }

        access(self) fun borrowShardedMember(_ addr: Address) : &ShardedWallet.ShardedMember {
            return (&self.members[addr] as &ShardedWallet.ShardedMember?)!
        }

        pub fun getVaultBalances() : {Type : UFix64} {
            let balances : {Type : UFix64} = {}
            for type in self.vaults.keys {
                let vault = self.borrowVault(type)
                balances[type] = vault.balance 
            }
            return balances
        }

        pub fun getMember(_ member: Address) : ShardedMember? {
            return self.members[member]
        }

        pub fun getMembers() : {Address: ShardedMember} {
            return self.members
        }

        pub fun setMembers(_ members: {Address: ShardedMember} ) {

            // send out all the contributions and empty the vaults before setting a new member
            self.distributeAll()
            // if the vaults are not empties, panic and report users that cannot send fund to
            if self.vaults.length > 0 {
                var msg = ""
                for member in self.members.values {
                    if member.claimable.length > 0 {
                        var FTtype = ""
                        for type in member.claimable.keys {
                            FTtype = FTtype.concat(" ").concat(type.identifier)
                        }
                        msg = msg.concat("User : ").concat(member.owner.toString()).concat("cannot receive fund in type ").concat(FTtype)
                        panic(msg)
                    }
                }
            }

            ShardedWallet.assertMembers(members)
            self.members=members
        }

        access(contract) fun setReceiver(member: Address, receivers: [{Receiver}]) {
            pre {
                self.members.containsKey(member) : "Member does not exist. Address : ".concat(member.toString())
            }
            let memberRef = self.borrowShardedMember(member)
            memberRef.setReceiver(receivers)
        }

        pub fun enableAutoDistribution(member: Address, enable: Bool) {
            pre {
                self.members.containsKey(member) : "Member does not exist. Address : ".concat(member.toString())
            }
            let memberRef = self.borrowShardedMember(member)
            memberRef.enableAutoDistribution(enable)
        }

        // distribute
        //
        // Distribute the given amount according to the fractions of the members
        //
        pub fun distribute(type: Type, amount: UFix64) {
            let vault = self.borrowVault(type)
 
            for member in self.members.keys {
                let shardedMember= self.borrowShardedMember(member)
                let shardedAmount= amount* shardedMember.fraction

                // For distribute, if the claimable is already below the amount, that means the user is already claimed before, will skip this. 
                if shardedMember.claimable[type] == nil || shardedMember.claimable[type]! < shardedAmount {
                    continue
                }
                let returnedVault <- shardedMember.deposit(from: <- vault.withdraw(amount: shardedAmount))
                if returnedVault.balance != 0.0 {
                    emit TokensFailedToDistribute(amount: returnedVault.balance, to: shardedMember.owner, type: returnedVault.getType().identifier)
                }
                vault.deposit(from: <-returnedVault)

                if vault.balance == 0.0 {
                    destroy self.vaults.remove(key: type)
                }
                emit TokensDistributed(amount:shardedAmount, to:shardedMember.owner, toName: shardedMember.name, type: type.identifier)
                
            } 
            emit TokensDistributedTotal(amount: amount, type: type.identifier)
        }

        pub fun distributeByType(type: Type) {
            let vault = self.borrowVault(type)
            var amount = 0.0

            for member in self.members.keys {
                let shardedMember= self.borrowShardedMember(member)
                let shardedAmount= shardedMember.claimable[type] ?? 0.0
                amount = amount + shardedAmount

                // For distribute, if the claimable is already below the amount, that means the user is already claimed before, will skip this. 
                if shardedAmount > 0.0 {
                    let returnedVault <- shardedMember.deposit(from: <- vault.withdraw(amount: shardedAmount))
                    if returnedVault.balance != 0.0 {
                        emit TokensFailedToDistribute(amount: returnedVault.balance, to: shardedMember.owner, type: returnedVault.getType().identifier)
                    }
                    vault.deposit(from: <-returnedVault)

                    if vault.balance == 0.0 {
                        destroy self.vaults.remove(key: type)
                    }
                    emit TokensDistributed(amount:shardedAmount, to:shardedMember.owner, toName: shardedMember.name, type: type.identifier)
                }
            } 
            emit TokensDistributedTotal(amount: amount, type: type.identifier)
        }

        pub fun distributeAll() {
            let types = self.vaults.keys
            for type in types {
                self.distributeByType(type: type)
            }
        }

        // claim 
        // 
        // functions called by individual contributors to get their portion of the wallet
        pub fun claim(member: Address, type: Type, amount: UFix64){
            pre{
                self.members.containsKey(member) : "This is not a sharded wallet member. Address : ".concat(member.toString())
            }
            let vault = self.borrowVault(type)
            if vault.balance < amount {
                panic("Not enough balance to distribute that amount. Vault balance : ".concat(vault.balance.toString()).concat(" Required balance : ").concat(amount.toString()))
            }
            let shardedMember= self.borrowShardedMember(member)
            let shardedAmount= amount
            let returnedVault <- shardedMember.deposit(from: <- vault.withdraw(amount: shardedAmount))
            if returnedVault.balance != 0.0 {
                emit TokensFailedToDistribute(amount: returnedVault.balance, to: shardedMember.owner, type: returnedVault.getType().identifier)
            } else {
                emit TokensDistributed(amount:shardedAmount, to:shardedMember.owner, toName: shardedMember.name, type: type.identifier)
            }
            vault.deposit(from: <-returnedVault)

            if vault.balance == 0.0 {
                destroy self.vaults.remove(key: type)
            }
        }

        // getShardedMember
        //
        // returns claimable amount of a sharded member 
        pub fun getShardedMember(member: Address) : ShardedMember? {
            return self.members[member]
        }

        // deposit
        //
        // delegate the deposit to the wrapped vault 
        pub fun deposit(from: @FungibleToken.Vault) {
            let type = from.getType()
            let balance = from.balance

            if self.vaults.containsKey(type){
                let vault = self.borrowVault(type)
                vault.deposit(from: <- from)
            } else {
                self.vaults[type] <-! from
            }

           // add claimable limit to SharedMember struct, if distribute is true, funds will be distributed directly
            for member in self.members.keys {
                let shardedMember= self.borrowShardedMember(member)
                let shardedAmount= balance* shardedMember.fraction
                shardedMember.addContribution(type: type, amount: shardedAmount)
                if shardedMember.distribute { 
                    self.claim(member: shardedMember.owner, type: type, amount: shardedAmount)
                } else {
                    emit TokensDepositedToShardedWallet(amount: shardedAmount, walletAddress: self.owner!.address, to: shardedMember.owner, type: type.identifier)
                }
            }
            emit TokensDepositedToShardedWalletTotal(amount: balance, walletAddress: self.owner!.address, type: type.identifier)
        }

        destroy() {
            self.distributeAll()
            destroy self.vaults
        }
    }

    pub fun assertMembers(_ members: {Address:ShardedMember}) {
         var total:UFix64=0.0
        for member in members.keys {
            let shardedMember= members[member]!
            for receiver in shardedMember.receivers.values {
                for type in receiver.getAcceptTypes(){
                    if !receiver.checkReceiver(type)  {
                        panic("Receiver needs to exist for member ".concat(member.toString()).concat(" . Type : ").concat(type.identifier))
                    }
                }
            }
            total = total+shardedMember.fraction
        }
        if total !=1.0 {
            panic("Cannot create vault without fully distributing the rewards")
        }
    }
    // createWallet
    //
    pub fun createWallet(members: {Address:ShardedMember}): @ShardedWallet.Wallet {
        self.assertMembers(members)
        return <-create Wallet(members: members)
    }

    // implementing https://docs.onflow.org/cadence/design-patterns#capability-receiver
    // this allows other accounts create a client that the owner of the ShardedWallet will add a server to
    pub resource interface ClientPublic {
        pub fun addServer(name: String, cap: Capability<&Wallet>) 
        pub fun getAllWallets() : {String : ShardedWallet.ShardedMember}
    }

    // Client Wallet is stored in the contributor's storage, they should be able to manage the funds to their own portion. 
    // For example, they should be able to claim their own portion, toggle auto distribution, add wallet receiver. But not managing others fund
    pub resource Client:ClientPublic {

        // Mapping of capability address to capability (To enable multi wallet controls)
        access(self) var servers: {Address : Capability<&Wallet>}

        // Mapping of wallet names to address. Provide convenient way to note and call the wallets. 
        access(self) var serverMap: {String : Address}

        init() {
            self.servers = {}
            self.serverMap = {}
        }

        pub fun addServer(name: String, cap: Capability<&Wallet>) {
            pre {
                cap.check() : "Invalid server capablity"
                !self.servers.containsKey(cap.address) : "Capability of wallet to address is already set : ".concat(cap.address.toString())
            }
            // set capability to mapping
            self.servers[cap.address] = cap

            // set wallet name map.  
            // If wallet name already exist, append wallet address at the end for identification, users can rename the wallet later. 
            if self.serverMap[name] == nil {
                self.serverMap[name] = cap.address 
            } else {
                let name = name.concat("_").concat(cap.address.toString())
                self.serverMap[name] = cap.address 
            }
        }

        pub fun renameWallet(oldName: String, newName: String) {
            pre{
                self.serverMap.containsKey(oldName) : "Wallet of this name does not exist. Name : ".concat(oldName)
                !self.serverMap.containsKey(newName) : "Wallet of this name already exist. Name : ".concat(newName)
            }
            self.serverMap[newName] = self.serverMap.remove(key: oldName)!
        }

        pub fun getAllWallets() : {String : ShardedWallet.ShardedMember} {
            let res : {String : ShardedWallet.ShardedMember} = {}
            for name in self.serverMap.keys {
                let serverAddress = self.serverMap[name]!
                res[name] = self.servers[serverAddress]!.borrow()!.getMember(self.owner!.address)
            }
            return res
        }

        pub fun claimAllInWallet(name: String) {
            let walletAddress=self.serverMap[name] ?? panic("Wallet does not exist. Name : ".concat(name))
            let walletCap=self.servers[walletAddress] ?? panic("Wallet does not exist. Address : ".concat(walletAddress.toString()))
            if !walletCap.check() {
                // emit events here to notify that the wallet is not valid anymore
                return
            }
            let walletRef = walletCap.borrow()!
            let claimable = walletRef.getShardedMember(member: self.owner!.address)!.claimable
            for type in claimable.keys {
                walletRef.claim(member: self.owner!.address, type: type, amount: claimable[type]!)
            }
        }

        pub fun claimByWalletType(name: String, type: Type, amount: UFix64) {
            let walletAddress=self.serverMap[name] ?? panic("Wallet does not exist. Name : ".concat(name))
            let walletCap=self.servers[walletAddress] ?? panic("Wallet does not exist. Address : ".concat(walletAddress.toString()))
            if !walletCap.check() {
                // emit events here to notify that the wallet is not valid anymore
                return
            }
            let walletRef = walletCap.borrow()!
            walletRef.claim(member: self.owner!.address, type: type, amount: amount)
        }

        pub fun setReceiver(name: String, receivers: [{Receiver}]) {
            let walletAddress=self.serverMap[name] ?? panic("Wallet does not exist. Name : ".concat(name))
            let walletCap=self.servers[walletAddress] ?? panic("Wallet does not exist. Address : ".concat(walletAddress.toString()))
            if !walletCap.check() {
                panic("Wallet capability is not valid. Wallet Name : ".concat(name))
            }
            let walletRef = walletCap.borrow()!
            walletRef.setReceiver(member: self.owner!.address, receivers: receivers)
        }

        pub fun enableAutoDistribution(name: String, enable: Bool) {
            let walletAddress=self.serverMap[name] ?? panic("Wallet does not exist. Name : ".concat(name))
            let walletCap=self.servers[walletAddress] ?? panic("Wallet does not exist. Address : ".concat(walletAddress.toString()))
            if !walletCap.check() {
                panic("Wallet capability is not valid. Wallet Name : ".concat(name))
            }
            let walletRef = walletCap.borrow()!
            walletRef.enableAutoDistribution(member: self.owner!.address, enable: enable)
        }

    }

    pub fun createClient(): @ShardedWallet.Client {
        return <- create Client()
    }

    init(){
        self.shardedWalletStoragePath = /storage/shardedWallet
        self.shardedWalletPrivatePath = /private/shardedWallet
        self.shardedWalletReceiverPath = /public/shardedWallet
        self.shardedWalletClientStoragePath = /storage/shardedWalletClient
        self.shardedWalletClientPrivatePath = /private/shardedWalletClient
        self.shardedWalletClientPublicPath = /public/shardedWalletClient
    }
}
   

   
 