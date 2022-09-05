package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
)

type OverflowTestUtils struct {
	T *testing.T
	O *OverflowState
}

func NewOverflowTest(t *testing.T) *OverflowTestUtils {
	o := Overflow(
		WithNetwork("testing"),
		WithFlowForNewUsers(100.0),
	)
	return &OverflowTestUtils{
		T: t,
		O: o,
	}
}

func (otu *OverflowTestUtils) setupWalletClient(user string) *OverflowTestUtils {
	otu.O.Tx("setup_shardedwallet_client",
		WithSigner(user),
	).
		AssertSuccess(otu.T)

	return otu
}

func (otu *OverflowTestUtils) setupAllWallet() *OverflowTestUtils {
	otu.setupWalletClient("user1").
		setupWalletClient("user2").
		setupWalletClient("user3").
		setupWalletClient("user4")

	args := []string{"user1", "user2", "user3", "user4"}

	otu.O.Tx("setup_wallet",
		WithSigner("wallet"),
		WithArg("memberNames", args),
		WithAddresses("memberAddresses", args...),
		WithArg("memberCuts", `[0.1, 0.2, 0.3, 0.4]`),
	).
		AssertSuccess(otu.T)

	return otu
}

func (otu *OverflowTestUtils) depositToWallet() OverflowResult {
	res := otu.O.Tx("deposit",
		WithSigner("service"),
		WithArg("receiver", "wallet"),
		WithArg("amount", 10.0),
	).
		AssertSuccess(otu.T)

	return res
}

func (otu *OverflowTestUtils) toggleWalletDistribution(user, name string, enable bool) OverflowResult {
	res := otu.O.Tx("toggleWalletDistribution",
		WithSigner(user),
		WithArg("name", name),
		WithArg("enable", enable),
	).
		AssertSuccess(otu.T)

	return res
}
