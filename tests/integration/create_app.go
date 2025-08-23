package integration

import (
	"encoding/json"
	"fmt"

	dbm "github.com/cosmos/cosmos-db"
	"github.com/cosmos/evm"
	testconfig "github.com/cosmos/evm/testutil/config"
	"github.com/cosmos/evm/testutil/constants"
	feemarkettypes "github.com/cosmos/evm/x/feemarket/types"
	ibctesting "github.com/cosmos/ibc-go/v10/testing"
	app "github.com/mail-chat-chain/mailchatd/app"
	"github.com/mail-chat-chain/mailchatd/config"

	clienthelpers "cosmossdk.io/client/v2/helpers"
	"cosmossdk.io/log"

	"github.com/cosmos/cosmos-sdk/baseapp"
	simutils "github.com/cosmos/cosmos-sdk/testutil/sims"
	minttypes "github.com/cosmos/cosmos-sdk/x/mint/types"
	stakingtypes "github.com/cosmos/cosmos-sdk/x/staking/types"
)

// CreateEvmd creates an evm app for regular integration tests (non-mempool)
// This version uses a noop mempool to avoid state issues during transaction processing
func CreateEvmd(chainID string, evmChainID uint64, customBaseAppOptions ...func(*baseapp.BaseApp)) evm.EvmApp {
	defaultNodeHome, err := clienthelpers.GetNodeHomeDirectory(fmt.Sprintf(".%s", config.AppName))
	if err != nil {
		panic(err)
	}

	db := dbm.NewMemDB()
	logger := log.NewNopLogger()
	loadLatest := true
	appOptions := simutils.NewAppOptionsWithFlagHome(defaultNodeHome)

	baseAppOptions := append(customBaseAppOptions, baseapp.SetChainID(chainID))

	return app.NewEVMApp(
		logger,
		db,
		nil,
		loadLatest,
		appOptions,
		evmChainID,
		testconfig.EvmAppOptions,
		baseAppOptions...,
	)
}

// SetupEvmd initializes a new evmd app with default genesis state.
// It is used in IBC integration tests to create a new evmd app instance.
func SetupEvmd() (ibctesting.TestingApp, map[string]json.RawMessage) {
	app := app.NewEVMApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simutils.EmptyAppOptions{},
		constants.ExampleEIP155ChainID,
		testconfig.EvmAppOptions,
	)
	// disable base fee for testing
	genesisState := app.DefaultGenesis()
	fmGen := feemarkettypes.DefaultGenesisState()
	fmGen.Params.NoBaseFee = true
	genesisState[feemarkettypes.ModuleName] = app.AppCodec().MustMarshalJSON(fmGen)
	stakingGen := stakingtypes.DefaultGenesisState()
	stakingGen.Params.BondDenom = config.ExampleChainDenom
	genesisState[stakingtypes.ModuleName] = app.AppCodec().MustMarshalJSON(stakingGen)
	mintGen := minttypes.DefaultGenesisState()
	mintGen.Params.MintDenom = config.ExampleChainDenom
	genesisState[minttypes.ModuleName] = app.AppCodec().MustMarshalJSON(mintGen)

	return app, genesisState
}
