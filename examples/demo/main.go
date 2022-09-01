package main

import (
	"fmt"

	. "github.com/bjartek/overflow"
)

// NB! start from root dir with makefile
func main() {

	// flow := gwtf.NewGoWithTheFlowEmulator()
	// fmt.Println("Demo of shared wallet")
	// flow.CreateAccountWithContracts("accounts", "ShardedWallet")

	// flow.CreateAccount("user1", "user2")
	// flow.TransactionFromFile("setup_shardedwallet_client").SignProposeAndPayAs("user1").Run()
	// flow.TransactionFromFile("setup_shardedwallet_client").SignProposeAndPayAs("user2").Run()
	// flow.TransactionFromFile("mint_tokens").SignProposeAndPayAsService().AccountArgument("user1").UFix64Argument("10.0").RunPrintEventsFull()

	// flow.TransactionFromFile("setup_wallet").SignProposeAndPayAs("user1").AccountArgument("user2").RunPrintEventsFull()
	// flow.TransactionFromFile("deposit").SignProposeAndPayAs("user1").UFix64Argument("10.0").RunPrintEventsFull()
	// flow.TransactionFromFile("distribute").SignProposeAndPayAs("user2").UFix64Argument("10.0").RunPrintEventsFull()

	account := "account"

	user1 := "user1"
	user2 := "user2"

	flow := Overflow(
		WithNetwork("embedded"),
		WithGlobalPrintOptions(),
	)
	fmt.Println("Demo of shared wallet")

	flow.Tx("setup_shardedwallet_client", WithSigner(user1))
	flow.Tx("setup_shardedwallet_client", WithSigner(user2))
	flow.Tx("mint_tokens", WithSigner(account),
		WithArg("recipient", user1),
		WithArg("amount", 10.0),
	)

	flow.Tx("setup_wallet", WithSigner(user1), WithArg("memberAddress", user2))
	flow.Tx("deposit", WithSigner(user1), WithArg("amount", 10.0))
	flow.Tx("distribute", WithSigner(user1), WithArg("amount", 10.0))

}
