import FlowToken from "../contracts/standard/FlowToken.cdc"

transaction(){
    prepare(account: AuthAccount) {
        account.unlink(/public/flowTokenReceiver)
    }
}