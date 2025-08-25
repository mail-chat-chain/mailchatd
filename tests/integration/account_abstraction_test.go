package integration_test

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/cosmos/cosmos-sdk/crypto/keys/secp256k1"
	cryptotypes "github.com/cosmos/cosmos-sdk/crypto/types"
	"github.com/cosmos/evm/testutil/integration/evm/factory"
	"github.com/cosmos/evm/testutil/integration/evm/grpc"
	"github.com/cosmos/evm/testutil/integration/evm/network"
	"github.com/cosmos/evm/testutil/keyring"
	evmtypes "github.com/cosmos/evm/x/vm/types"

	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

type AccountAbstractionSuite struct {
	suite.Suite

	network network.Network
	factory factory.TxFactory
	grpc    grpc.Handler
	keyring keyring.Keyring

	// Account Abstraction precompile address
	aaPrecompileAddr common.Address
}

func TestAccountAbstractionSuite(t *testing.T) {
	suite.Run(t, new(AccountAbstractionSuite))
}

func (s *AccountAbstractionSuite) SetupSuite() {
	keyring := keyring.New(2)
	integrationNetwork := network.New(
		integration.CreateEvmd,
		network.WithPreFundedAccounts(keyring.GetAllAccAddrs()...),
	)

	grpcHandler := grpc.NewIntegrationHandler(integrationNetwork)
	txFactory := factory.New(integrationNetwork, grpcHandler)

	s.network = integrationNetwork
	s.factory = txFactory
	s.grpc = grpcHandler
	s.keyring = keyring
	s.aaPrecompileAddr = common.HexToAddress("0x0000000000000000000000000000000000000808")
}

func (s *AccountAbstractionSuite) TestAccountAbstractionPrecompileExists() {
	// Test that the account abstraction precompile is available at the expected address
	
	// Get the account at the precompile address
	account, err := s.grpc.GetEvmAccount(s.aaPrecompileAddr)
	s.Require().NoError(err)
	s.Require().NotNil(account)
	
	// The precompile should have code (even if it's just a marker)
	s.T().Logf("Account abstraction precompile at address: %s", s.aaPrecompileAddr.String())
}

func (s *AccountAbstractionSuite) TestValidateUserOp() {
	// Test the validateUserOp method of the account abstraction precompile
	
	// Prepare test data
	sender := s.keyring.GetAddr(0)
	privateKey := s.keyring.GetPrivKey(0)
	
	// Create a mock user operation
	userOp := s.createMockUserOperation(sender, privateKey)
	
	// Call the validateUserOp precompile method
	methodID := []byte{0x00, 0x00, 0x00, 0x01} // validateUserOp method ID
	callData := s.encodeUserOperationForValidation(userOp, methodID)
	
	// Execute the precompile call
	result, err := s.callPrecompile(s.aaPrecompileAddr, callData, sender)
	s.Require().NoError(err)
	s.Require().NotNil(result)
	
	s.T().Logf("ValidateUserOp result: %s", hexutil.Encode(result))
}

func (s *AccountAbstractionSuite) TestGetUserOpHash() {
	// Test the getUserOpHash method of the account abstraction precompile
	
	sender := s.keyring.GetAddr(0)
	privateKey := s.keyring.GetPrivKey(0)
	
	// Create a mock user operation
	userOp := s.createMockUserOperation(sender, privateKey)
	
	// Call the getUserOpHash precompile method
	methodID := []byte{0x00, 0x00, 0x00, 0x02} // getUserOpHash method ID
	callData := s.encodeUserOperationForHash(userOp, methodID)
	
	// Execute the precompile call
	result, err := s.callPrecompile(s.aaPrecompileAddr, callData, sender)
	s.Require().NoError(err)
	s.Require().NotNil(result)
	s.Require().Len(result, 32) // Should return a 32-byte hash
	
	s.T().Logf("GetUserOpHash result: %s", hexutil.Encode(result))
}

func (s *AccountAbstractionSuite) TestCreateAccount() {
	// Test the createAccount method of the account abstraction precompile
	
	owner := s.keyring.GetAddr(0)
	salt := big.NewInt(12345)
	
	// Call the createAccount precompile method
	methodID := []byte{0x00, 0x00, 0x00, 0x03} // createAccount method ID
	callData := s.encodeCreateAccount(owner, salt, methodID)
	
	// Execute the precompile call
	result, err := s.callPrecompile(s.aaPrecompileAddr, callData, owner)
	s.Require().NoError(err)
	s.Require().NotNil(result)
	s.Require().Len(result, 32) // Should return a 32-byte address
	
	// Extract the created account address
	accountAddr := common.BytesToAddress(result[12:]) // Last 20 bytes
	s.Require().NotEqual(common.Address{}, accountAddr)
	
	s.T().Logf("CreateAccount result: %s", accountAddr.String())
}

func (s *AccountAbstractionSuite) TestGetAccountNonce() {
	// Test the getAccountNonce method of the account abstraction precompile
	
	account := s.keyring.GetAddr(0)
	key := big.NewInt(0) // Default nonce key
	
	// Call the getAccountNonce precompile method
	methodID := []byte{0x00, 0x00, 0x00, 0x04} // getAccountNonce method ID
	callData := s.encodeGetAccountNonce(account, key, methodID)
	
	// Execute the precompile call
	result, err := s.callPrecompile(s.aaPrecompileAddr, callData, account)
	s.Require().NoError(err)
	s.Require().NotNil(result)
	s.Require().Len(result, 32) // Should return a 32-byte nonce
	
	// Extract the nonce
	nonce := new(big.Int).SetBytes(result)
	s.Require().NotNil(nonce)
	
	s.T().Logf("GetAccountNonce result: %s", nonce.String())
}

// Helper methods

func (s *AccountAbstractionSuite) createMockUserOperation(sender common.Address, privateKey cryptotypes.PrivKey) map[string]interface{} {
	return map[string]interface{}{
		"sender":               sender,
		"nonce":                big.NewInt(0),
		"initCode":             []byte{},
		"callData":             []byte{},
		"callGasLimit":         big.NewInt(200000),
		"verificationGasLimit": big.NewInt(100000),
		"preVerificationGas":   big.NewInt(50000),
		"maxFeePerGas":         big.NewInt(1000000000), // 1 gwei
		"maxPriorityFeePerGas": big.NewInt(1000000000), // 1 gwei
		"paymasterAndData":     []byte{},
		"signature":            s.createMockSignature(sender, privateKey),
	}
}

func (s *AccountAbstractionSuite) createMockSignature(sender common.Address, privateKey cryptotypes.PrivKey) []byte {
	// Convert Cosmos PrivKey to ECDSA private key
	secp256k1Key, ok := privateKey.(*secp256k1.PrivKey)
	if !ok {
		s.T().Fatal("Expected secp256k1 private key")
	}
	
	ecdsaPrivKey, err := crypto.ToECDSA(secp256k1Key.Bytes())
	s.Require().NoError(err)
	
	// Create a simple mock signature
	hash := crypto.Keccak256Hash(append(sender.Bytes(), []byte("mock_user_operation")...))
	signature, err := crypto.Sign(hash.Bytes(), ecdsaPrivKey)
	s.Require().NoError(err)
	return signature
}

func (s *AccountAbstractionSuite) encodeUserOperationForValidation(userOp map[string]interface{}, methodID []byte) []byte {
	// This is a simplified encoding for testing
	// In a real implementation, this would use proper ABI encoding
	
	data := make([]byte, 0)
	data = append(data, methodID...)
	
	// Add mock user operation data (simplified)
	sender := userOp["sender"].(common.Address)
	data = append(data, sender.Bytes()...)
	
	// Add mock hash
	mockHash := make([]byte, 32)
	copy(mockHash, []byte("mock_user_op_hash"))
	data = append(data, mockHash...)
	
	// Add required prefund (mock value)
	prefund := make([]byte, 32)
	copy(prefund[24:], big.NewInt(1000000).Bytes())
	data = append(data, prefund...)
	
	return data
}

func (s *AccountAbstractionSuite) encodeUserOperationForHash(userOp map[string]interface{}, methodID []byte) []byte {
	// Simplified encoding for getUserOpHash
	data := make([]byte, 0)
	data = append(data, methodID...)
	
	// Add mock user operation data
	sender := userOp["sender"].(common.Address)
	data = append(data, sender.Bytes()...)
	
	return data
}

func (s *AccountAbstractionSuite) encodeCreateAccount(owner common.Address, salt *big.Int, methodID []byte) []byte {
	// Simplified encoding for createAccount
	data := make([]byte, 0)
	data = append(data, methodID...)
	
	// Add owner address (padded to 32 bytes)
	ownerBytes := make([]byte, 32)
	copy(ownerBytes[12:], owner.Bytes())
	data = append(data, ownerBytes...)
	
	// Add salt (padded to 32 bytes)
	saltBytes := make([]byte, 32)
	salt.FillBytes(saltBytes)
	data = append(data, saltBytes...)
	
	return data
}

func (s *AccountAbstractionSuite) encodeGetAccountNonce(account common.Address, key *big.Int, methodID []byte) []byte {
	// Simplified encoding for getAccountNonce
	data := make([]byte, 0)
	data = append(data, methodID...)
	
	// Add account address (padded to 32 bytes)
	accountBytes := make([]byte, 32)
	copy(accountBytes[12:], account.Bytes())
	data = append(data, accountBytes...)
	
	// Add key (padded to 24 bytes for uint192)
	keyBytes := make([]byte, 24)
	key.FillBytes(keyBytes)
	data = append(data, keyBytes...)
	
	return data
}

func (s *AccountAbstractionSuite) callPrecompile(target common.Address, data []byte, from common.Address) ([]byte, error) {
	// Execute a call to the precompile contract
	senderPrivateKey := s.keyring.GetPrivKey(0)
	
	// Create transaction arguments
	txArgs := evmtypes.EvmTxArgs{
		To:       &target,
		GasLimit: uint64(1000000),
		GasPrice: big.NewInt(1000000000), // 1 gwei
		Input:    data,
	}
	
	// Execute the transaction
	res, err := s.factory.ExecuteEthTx(senderPrivateKey, txArgs)
	if err != nil {
		return nil, err
	}
	
	// Decode the EVM transaction response
	evmRes, err := evmtypes.DecodeTxResponse(res.Data)
	if err != nil {
		return nil, err
	}
	
	if evmRes.Failed() {
		return nil, fmt.Errorf("transaction failed: %s", evmRes.VmError)
	}
	
	return evmRes.Ret, nil
}

func (s *AccountAbstractionSuite) TestEnd2EndUserOperation() {
	// End-to-end test for a complete user operation flow
	s.T().Log("Starting end-to-end Account Abstraction test")
	
	// 1. Create account
	owner := s.keyring.GetAddr(0)
	salt := big.NewInt(123)
	
	createAccountData := s.encodeCreateAccount(owner, salt, []byte{0x00, 0x00, 0x00, 0x03})
	accountResult, err := s.callPrecompile(s.aaPrecompileAddr, createAccountData, owner)
	s.Require().NoError(err)
	
	accountAddr := common.BytesToAddress(accountResult[12:])
	s.T().Logf("Created account: %s", accountAddr.String())
	
	// 2. Get account nonce
	nonceData := s.encodeGetAccountNonce(accountAddr, big.NewInt(0), []byte{0x00, 0x00, 0x00, 0x04})
	nonceResult, err := s.callPrecompile(s.aaPrecompileAddr, nonceData, owner)
	s.Require().NoError(err)
	
	nonce := new(big.Int).SetBytes(nonceResult)
	s.T().Logf("Account nonce: %s", nonce.String())
	
	// 3. Create and validate user operation
	userOp := s.createMockUserOperation(accountAddr, s.keyring.GetPrivKey(0))
	validateData := s.encodeUserOperationForValidation(userOp, []byte{0x00, 0x00, 0x00, 0x01})
	validateResult, err := s.callPrecompile(s.aaPrecompileAddr, validateData, owner)
	s.Require().NoError(err)
	
	validationData := new(big.Int).SetBytes(validateResult)
	s.T().Logf("Validation result: %s", validationData.String())
	s.Require().Equal(int64(0), validationData.Int64()) // Should be 0 for success
	
	// 4. Get user operation hash
	hashData := s.encodeUserOperationForHash(userOp, []byte{0x00, 0x00, 0x00, 0x02})
	hashResult, err := s.callPrecompile(s.aaPrecompileAddr, hashData, owner)
	s.Require().NoError(err)
	
	userOpHash := common.BytesToHash(hashResult)
	s.T().Logf("UserOp hash: %s", userOpHash.String())
	
	s.T().Log("End-to-end Account Abstraction test completed successfully")
}