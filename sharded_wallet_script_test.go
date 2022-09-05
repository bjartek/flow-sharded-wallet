package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
	"github.com/hexops/autogold"
	"github.com/stretchr/testify/assert"
)

func TestShardedWalletScript(t *testing.T) {

	flowTokenType := "A.0ae53cb6e3f42a79.FlowToken.Vault"

	t.Run("Should be able to get Wallet Members", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()
		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		otu.depositToWallet()

		res, err := otu.O.Script("getWalletMembers",
			WithArg("addr", "wallet"),
		).
			GetAsInterface()

		assert.NoError(t, err)
		assert.Equal(t, 4, len(res.(map[string]interface{})))

	})

	t.Run("Should be able to get Wallet Vault Balance", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()
		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		otu.depositToWallet()

		otu.O.Script("getWalletVaultBalance",
			WithArg("addr", "wallet"),
		).
			// 3 Flow has been auto-distributed
			AssertWithPointerWant(t, "/"+flowTokenType, autogold.Want("getWalletVaultBalance", 7.0))

	})

	t.Run("Should be able to get all sharded wallets of a user", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()
		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		args := []string{"user1", "user2", "user3", "user4"}

		otu.O.Tx("setup_wallet",
			WithSigner("user1"),
			WithArg("memberNames", args),
			WithAddresses("memberAddresses", args...),
			WithArg("memberCuts", `[0.1, 0.2, 0.3, 0.4]`),
		).
			AssertSuccess(otu.T)

		otu.depositToWallet()

		res, err := otu.O.Script("getAllWallets",
			WithArg("addr", "user1"),
		).
			GetAsInterface()

		assert.NoError(t, err)
		assert.Equal(t, 2, len(res.(map[string]interface{})))

	})

	t.Run("Should be able to get total claimable amounts of a user", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		args := []string{"user1", "user2", "user3", "user4"}

		otu.O.Tx("setup_wallet",
			WithSigner("user1"),
			WithArg("memberNames", args),
			WithAddresses("memberAddresses", args...),
			WithArg("memberCuts", `[0.1, 0.2, 0.3, 0.4]`),
		).
			AssertSuccess(otu.T)

		otu.depositToWallet()

		otu.O.Script("getClaimables",
			WithArg("addr", "user1"),
		).
			Print().
			AssertWithPointerWant(t, "/total/"+flowTokenType, autogold.Want("getClaimables", 1.0)).
			AssertWithPointerWant(t, "/wallets/user1/"+flowTokenType, autogold.Want("getClaimables", 1.0))

	})

}
