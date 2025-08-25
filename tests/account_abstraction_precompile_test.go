package tests

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/stretchr/testify/require"

	aaprecompile "github.com/mail-chat-chain/mailchatd/precompiles/account_abstraction"
)

func TestAccountAbstractionPrecompile(t *testing.T) {
	precompile := aaprecompile.NewPrecompile()

	t.Run("Address", func(t *testing.T) {
		expectedAddr := common.HexToAddress("0x0000000000000000000000000000000000000808")
		require.Equal(t, expectedAddr, precompile.Address())
	})

	t.Run("RequiredGas", func(t *testing.T) {
		// Test validateUserOp method (0x00000001)
		input := []byte{0x00, 0x00, 0x00, 0x01}
		gas := precompile.RequiredGas(input)
		require.Equal(t, uint64(50000), gas)

		// Test getUserOpHash method (0x00000002)
		input = []byte{0x00, 0x00, 0x00, 0x02}
		gas = precompile.RequiredGas(input)
		require.Equal(t, uint64(10000), gas)

		// Test createAccount method (0x00000003)
		input = []byte{0x00, 0x00, 0x00, 0x03}
		gas = precompile.RequiredGas(input)
		require.Equal(t, uint64(100000), gas)

		// Test getAccountNonce method (0x00000004)
		input = []byte{0x00, 0x00, 0x00, 0x04}
		gas = precompile.RequiredGas(input)
		require.Equal(t, uint64(5000), gas)

		// Test invalid input
		input = []byte{0x00, 0x00, 0x00, 0x99}
		gas = precompile.RequiredGas(input)
		require.Equal(t, uint64(10000), gas) // Default gas cost
	})

	t.Run("Run", func(t *testing.T) {
		// Create a mock EVM environment
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00, 0x00, 0x01}, // validateUserOp method
		}

		result, err := precompile.Run(evm, contract, false)
		require.NoError(t, err)
		require.NotNil(t, result)
		require.Len(t, result, 32) // Should return a 32-byte result

		// Check that result is 0 (success)
		resultInt := new(big.Int).SetBytes(result)
		require.Equal(t, int64(0), resultInt.Int64())
	})

	t.Run("RunGetUserOpHash", func(t *testing.T) {
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00, 0x00, 0x02}, // getUserOpHash method
		}

		result, err := precompile.Run(evm, contract, false)
		require.NoError(t, err)
		require.NotNil(t, result)
		require.Len(t, result, 32) // Should return a 32-byte hash
	})

	t.Run("RunCreateAccount", func(t *testing.T) {
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00, 0x00, 0x03}, // createAccount method
		}

		result, err := precompile.Run(evm, contract, false)
		require.NoError(t, err)
		require.NotNil(t, result)
		require.Len(t, result, 32) // Should return a 32-byte address
	})

	t.Run("RunGetAccountNonce", func(t *testing.T) {
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00, 0x00, 0x04}, // getAccountNonce method
		}

		result, err := precompile.Run(evm, contract, false)
		require.NoError(t, err)
		require.NotNil(t, result)
		require.Len(t, result, 32) // Should return a 32-byte nonce
	})

	t.Run("RunInvalidMethod", func(t *testing.T) {
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00, 0x00, 0x99}, // Invalid method
		}

		result, err := precompile.Run(evm, contract, false)
		require.Error(t, err)
		require.Nil(t, result)
		require.Equal(t, vm.ErrExecutionReverted, err)
	})

	t.Run("RunInvalidInput", func(t *testing.T) {
		evm := &vm.EVM{}
		contract := &vm.Contract{
			Input: []byte{0x00, 0x00}, // Too short input
		}

		result, err := precompile.Run(evm, contract, false)
		require.Error(t, err)
		require.Nil(t, result)
		require.Equal(t, vm.ErrExecutionReverted, err)
	})
}