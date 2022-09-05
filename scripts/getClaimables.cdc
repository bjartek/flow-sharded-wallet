import ShardedWallet from "../contracts/ShardedWallet.cdc"

pub fun main(addr: Address) : Report {
    let ref = getAccount(addr).getCapability<&ShardedWallet.Client{ShardedWallet.ClientPublic}>(ShardedWallet.shardedWalletClientPublicPath).borrow()!
    let data = ref.getAllWallets()
    let wallets : {String : { String : UFix64 }} = {}
    let total : {String : UFix64} = {}
    for name in data.keys {
        let wallet : { String : UFix64 } = {}
        let claimable = data[name]!.claimable
        for key in claimable.keys {
            wallet[key.identifier] = claimable[key]!
        }
        wallets[name] = wallet
    }

    for wallet in wallets.values {
        for type in wallet.keys {
            let originalValue = total[type] ?? 0.0 
            total[type] = originalValue + wallet[type]!
        }
    }

    return Report(wallets: wallets, total: total)

} 

pub struct Report {
    pub let wallets : {String : { String : UFix64}}
    pub let total : {String : UFix64}

    init(wallets : {String : { String : UFix64}} , total : {String : UFix64}) {
        self.wallets = wallets 
        self.total = total
    }
}