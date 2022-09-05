package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
)

func TestShardedWallet(t *testing.T) {

	flowTokenType := "A.0ae53cb6e3f42a79.FlowToken.Vault"

	t.Run("Should be able to set up wallets", func(t *testing.T) {
		otu := NewOverflowTest(t)

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
			AssertSuccess(t)
	})

	t.Run("Should be able to deposit fund", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.O.Tx("deposit",
			WithSigner("service"),
			WithArg("receiver", "wallet"),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
			})

	})

	t.Run("Should be able to auto distribute fund", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		otu.depositToWallet().
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
			})

	})

	t.Run("Should emit failed to distribute event when failed to auto distribute", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		// unlink user2 flow wallet
		otu.O.Tx("testUnlinkFlowVault",
			WithSigner("user2"),
		)

		otu.depositToWallet().
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensFailedToDistribute", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
			}).
			AssertEvent(t, "TokensDepositedToShardedWallet", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
			})

	})

	t.Run("Should be able to claim fund by Client", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		otu.O.Tx("claim",
			WithSigner("user1"),
			WithArg("name", "user1"),
			WithArg("type", flowTokenType),
			WithArg("amount", 1.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

		otu.O.Tx("claimAllInWallet",
			WithSigner("user2"),
			WithArg("name", "user2"),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			})

		otu.O.Tx("claimAll",
			WithSigner("user3"),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			})

	})

	t.Run("Wallet Admin Should be able to distribute fund", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distributeByType",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distributeAll",
			WithSigner("wallet"),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

	})

	t.Run("Should not be able to distribute fund exceeding vault balance", func(t *testing.T) {
		// Transactions will still go through because there is no panic mechanism to stop.
		// But the funds are not deposited to any user.

		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 100.0),
		).
			AssertSuccess(t)

	})

	t.Run("if someone already auto-distributed, they should skip distribution", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.toggleWalletDistribution("user1", "user1", true)
		otu.toggleWalletDistribution("user2", "user2", true)

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

	})

	t.Run("should be able to rename wallet and still claim / distribute", func(t *testing.T) {
		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		otu.O.Tx("renameWallet",
			WithSigner("user1"),
			WithArg("name", "user1"),
			WithArg("newName", "myTestWallet"),
		).
			AssertSuccess(t)

		otu.O.Tx("claim",
			WithSigner("user1"),
			WithArg("name", "myTestWallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 1.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

	})

	t.Run("should be able to set up more than 1 wallet", func(t *testing.T) {
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

		otu.O.Tx("renameWallet",
			WithSigner("user1"),
			WithArg("name", "user1"),
			WithArg("newName", "myTestWallet"),
		).
			AssertSuccess(t)

		otu.O.Tx("claim",
			WithSigner("user1"),
			WithArg("name", "myTestWallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 1.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

	})

	t.Run("should be able to set new receicer", func(t *testing.T) {

		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		otu.O.Tx("testSetReceiver",
			WithSigner("user1"),
			WithArg("name", "user1"),
		).
			AssertSuccess(t)

		otu.O.Tx("claim",
			WithSigner("user1"),
			WithArg("name", "user1"),
			WithArg("type", flowTokenType),
			WithArg("amount", 1.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			})

	})

	t.Run("Wallet Admin should be able to set new members", func(t *testing.T) {

		otu := NewOverflowTest(t)

		otu.setupAllWallet()

		otu.depositToWallet()

		args := []string{"user1", "user2", "user3", "user4"}

		otu.O.Tx("testSetMembers",
			WithSigner("wallet"),
			WithArg("memberNames", args),
			WithAddresses("memberAddresses", args...),
			WithArg("memberCuts", `[0.4, 0.3, 0.2, 0.1]`),
		).
			AssertSuccess(t).
			// Events here are distributing residuals to reset the member claimables
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

		otu.depositToWallet()

		otu.O.Tx("distribute",
			WithSigner("wallet"),
			WithArg("type", flowTokenType),
			WithArg("amount", 10.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 4.0,
				"to":     otu.O.Address("user1"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 3.0,
				"to":     otu.O.Address("user2"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 2.0,
				"to":     otu.O.Address("user3"),
				"type":   flowTokenType,
			}).
			AssertEvent(t, "TokensDistributed", map[string]interface{}{
				"amount": 1.0,
				"to":     otu.O.Address("user4"),
				"type":   flowTokenType,
			})

	})

}
