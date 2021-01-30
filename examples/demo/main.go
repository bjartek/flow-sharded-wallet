package main

import (
	"fmt"

	"github.com/bjartek/go-with-the-flow/gwtf"
)

//NB! start from root dir with makefile
func main() {

	flow := gwtf.NewGoWithTheFlowEmulator()
	fmt.Println("Demo of shared wallet")
	flow.CreateAccountWithContracts("accounts", "ShardedWallet")

	flow.CreateAccount("user1", "user2")
	flow.TransactionFromFile("setup_shardedwallet_client").SignProposeAndPayAs("user1").Run()
	flow.TransactionFromFile("setup_shardedwallet_client").SignProposeAndPayAs("user2").Run()
	flow.TransactionFromFile("mint_tokens").SignProposeAndPayAsService().AccountArgument("user1").UFix64Argument("10.0").RunPrintEventsFull()

	flow.TransactionFromFile("setup_wallet").SignProposeAndPayAs("user1").AccountArgument("user2").RunPrintEventsFull()
	flow.TransactionFromFile("deposit").SignProposeAndPayAs("user1").UFix64Argument("10.0").RunPrintEventsFull()
	flow.TransactionFromFile("distribute").SignProposeAndPayAs("user2").UFix64Argument("10.0").RunPrintEventsFull()

}
