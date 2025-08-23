package cmd

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/cosmos/go-bip39"
	"github.com/spf13/cobra"

	cmtcfg "github.com/cometbft/cometbft/config"
	"github.com/cometbft/cometbft/p2p"
	"github.com/cometbft/cometbft/privval"
	cmttypes "github.com/cometbft/cometbft/types"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/client/input"
	"github.com/cosmos/cosmos-sdk/server"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"

	evmconfig "github.com/mail-chat-chain/mailchatd/config"
)

const (
	// FlagOverwrite defines a flag to overwrite an existing genesis JSON file.
	FlagOverwrite = "overwrite"

	// FlagRecover defines a flag to initialize the private validator key from a specific seed.
	FlagRecover = "recover"

	// FlagDefaultBondDenom defines the default denom to use in the genesis file.
	FlagDefaultBondDenom = "default-denom"
)

// InitCmd returns a command to initialize all files needed for CometBFT
// and the respective application with an integrated genesis fix.
func InitCmd(bmm module.BasicManager, defaultNodeHome string) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init [moniker]",
		Short: "Initialize private validator, p2p, genesis, and application configuration files",
		Long:  `Initialize validators' and node' configuration files with integrated genesis configuration.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx := client.GetClientContextFromCmd(cmd)
			cdc := clientCtx.Codec

			serverCtx := server.GetServerContextFromCmd(cmd)
			config := serverCtx.Config

			config.SetRoot(clientCtx.HomeDir)

			chainID, _ := cmd.Flags().GetString(flags.FlagChainID)
			if chainID == "" {
				chainID = fmt.Sprintf("%s-%d", evmconfig.AppName, evmconfig.EVMChainID)
			}

			// Get bip39 mnemonic
			var mnemonic string
			recover, _ := cmd.Flags().GetBool(FlagRecover)
			if recover {
				inBuf := bufio.NewReader(cmd.InOrStdin())
				value, err := input.GetString("Enter your bip39 mnemonic", inBuf)
				if err != nil {
					return err
				}

				mnemonic = value
				if !bip39.IsMnemonicValid(mnemonic) {
					return errors.New("invalid mnemonic")
				}
			}

			// Get initial height
			initHeight, _ := cmd.Flags().GetInt64(flags.FlagInitHeight)
			if initHeight < 1 {
				initHeight = 1
			}

			nodeID, _, err := initializeNodeValidatorFilesFromMnemonic(config, mnemonic)
			if err != nil {
				return err
			}

			config.Moniker = args[0]

			genFile := config.GenesisFile()
			overwrite, _ := cmd.Flags().GetBool(FlagOverwrite)
			defaultDenom, _ := cmd.Flags().GetString(FlagDefaultBondDenom)
			
			// use os.Stat to check if the file exists
			_, err = os.Stat(genFile)
			if !overwrite && !os.IsNotExist(err) {
				return fmt.Errorf("genesis.json file already exists: %v", genFile)
			}

			// Overwrites the SDK default denom for side-effects
			if defaultDenom != "" {
				sdk.DefaultBondDenom = defaultDenom
			} else {
				sdk.DefaultBondDenom = evmconfig.BaseDenom
			}

			// Create app state
			appState, err := json.MarshalIndent(bmm.DefaultGenesis(cdc), "", " ")
			if err != nil {
				return fmt.Errorf("failed to marshal default genesis state: %w", err)
			}

			genDoc := &cmttypes.GenesisDoc{
				ChainID:    chainID,
				Validators: nil,
				AppState:   appState,
			}
			
			if err = genDoc.SaveAs(genFile); err != nil {
				return fmt.Errorf("failed to save genesis doc to file: %w", err)
			}

			// Apply integrated genesis configuration fixes
			if err := applyGenesisConfigFixes(genFile, initHeight); err != nil {
				return fmt.Errorf("failed to apply genesis configuration fixes: %w", err)
			}

			toPrint := newPrintInfo(config.Moniker, chainID, nodeID, "", appState)

			cfg := cmtcfg.DefaultConfig()
			cfg.SetRoot(clientCtx.HomeDir)
			cmtcfg.WriteConfigFile(filepath.Join(config.RootDir, "config", "config.toml"), cfg)

			return displayInfo(toPrint)
		},
	}

	cmd.Flags().String(flags.FlagHome, defaultNodeHome, "node's home directory")
	cmd.Flags().BoolP(FlagOverwrite, "o", false, "overwrite the genesis.json file")
	cmd.Flags().Bool(FlagRecover, false, "provide seed phrase to recover existing key instead of creating")
	cmd.Flags().String(flags.FlagChainID, "", "genesis file chain-id, if left blank will be randomly created")
	cmd.Flags().String(FlagDefaultBondDenom, "", "genesis file default denomination, if left blank default value is 'amcc'")
	cmd.Flags().Int64(flags.FlagInitHeight, 1, "specify the initial block height at genesis")

	return cmd
}

// GenesisDoc represents the structure of genesis.json for fixing
type GenesisDoc struct {
	AppState      map[string]json.RawMessage `json:"app_state"`
	ChainID       string                     `json:"chain_id"`
	AppName       string                     `json:"app_name,omitempty"`
	AppVersion    string                     `json:"app_version,omitempty"`
	GenesisTime   string                     `json:"genesis_time,omitempty"`
	InitialHeight json.Number                `json:"initial_height,omitempty"`
	AppHash       string                     `json:"app_hash"`
	Consensus     interface{}                `json:"consensus,omitempty"`
	Validators    []interface{}              `json:"validators,omitempty"`
}

// applyGenesisConfigFixes applies the same fixes that were done in fix_genesis.go
func applyGenesisConfigFixes(genesisPath string, initialHeight int64) error {
	// Read genesis file
	data, err := os.ReadFile(genesisPath)
	if err != nil {
		return fmt.Errorf("error reading genesis file: %w", err)
	}
	
	var genesis GenesisDoc
	if err := json.Unmarshal(data, &genesis); err != nil {
		return fmt.Errorf("error unmarshaling genesis: %w", err)
	}

	genesis.AppName = evmconfig.AppName
	genesis.AppVersion = evmconfig.Version  // Set app version from config
	genesis.InitialHeight = json.Number(fmt.Sprintf("%d", initialHeight))  // json.Number can handle both string and number formats
	
	// Set genesis_time to current time if not already set
	if genesis.GenesisTime == "" || genesis.GenesisTime == "0001-01-01T00:00:00Z" {
		genesis.GenesisTime = time.Now().UTC().Format(time.RFC3339)
	}
	
	// Preserve consensus if exists, otherwise set to default
	if genesis.Consensus == nil {
		genesis.Consensus = map[string]interface{}{
			"params": map[string]interface{}{
				"block": map[string]interface{}{
					"max_bytes": "22020096",
					"max_gas":   "-1",
				},
				"evidence": map[string]interface{}{
					"max_age_num_blocks": "100000",
					"max_age_duration":   "172800000000000",
					"max_bytes":          "1048576",
				},
				"validator": map[string]interface{}{
					"pub_key_types": []string{"ed25519"},
				},
				"version": map[string]interface{}{
					"app": "0",
				},
			},
		}
	}

	// Fix EVM module
	var evmState map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["evm"], &evmState); err == nil {
		if params, ok := evmState["params"].(map[string]interface{}); ok {
			params["evm_denom"] = evmconfig.BaseDenom
			
			// Add active static precompiles
			params["active_static_precompiles"] = []string{
				"0x0000000000000000000000000000000000000100",
				"0x0000000000000000000000000000000000000400",
				"0x0000000000000000000000000000000000000800",
				"0x0000000000000000000000000000000000000801",
				"0x0000000000000000000000000000000000000802",
				"0x0000000000000000000000000000000000000803",
				"0x0000000000000000000000000000000000000804",
				"0x0000000000000000000000000000000000000805",
				"0x0000000000000000000000000000000000000806",
				"0x0000000000000000000000000000000000000807",
			}
		}
		genesis.AppState["evm"], _ = json.Marshal(evmState)
	}
	
	// Fix staking module
	var stakingState map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["staking"], &stakingState); err == nil {
		if params, ok := stakingState["params"].(map[string]interface{}); ok {
			params["bond_denom"] = evmconfig.BaseDenom
		}
		genesis.AppState["staking"], _ = json.Marshal(stakingState)
	}
	
	// Fix mint module
	var mintState map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["mint"], &mintState); err == nil {
		if params, ok := mintState["params"].(map[string]interface{}); ok {
			params["mint_denom"] = evmconfig.BaseDenom
		}
		genesis.AppState["mint"], _ = json.Marshal(mintState)
	}
	
	// Fix gov module
	var govState map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["gov"], &govState); err == nil {
		if params, ok := govState["params"].(map[string]interface{}); ok {
			if minDeposit, ok := params["min_deposit"].([]interface{}); ok {
				for _, dep := range minDeposit {
					if deposit, ok := dep.(map[string]interface{}); ok {
						deposit["denom"] = evmconfig.BaseDenom
					}
				}
			}
			if expMinDeposit, ok := params["expedited_min_deposit"].([]interface{}); ok {
				for _, dep := range expMinDeposit {
					if deposit, ok := dep.(map[string]interface{}); ok {
						deposit["denom"] = evmconfig.BaseDenom
					}
				}
			}
		}
		genesis.AppState["gov"], _ = json.Marshal(govState)
	}
	
	// Add bank denom metadata
	var bankState map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["bank"], &bankState); err == nil {
		metadata := map[string]interface{}{
			"description": "The native staking token for mailchatd.",
			"denom_units": []map[string]interface{}{
				{
					"denom":    evmconfig.BaseDenom,
					"exponent": 0,
					"aliases":  []string{"atto" + evmconfig.DisplayDenom},
				},
				{
					"denom":    evmconfig.DisplayDenom,
					"exponent": 18,
					"aliases":  []string{},
				},
			},
			"base":     evmconfig.BaseDenom,
			"display":  evmconfig.DisplayDenom,
			"name":     "Mail Chat Coin",
			"symbol":   "MCC",
			"uri":      "",
			"uri_hash": "",
		}
		bankState["denom_metadata"] = []interface{}{metadata}
		genesis.AppState["bank"], _ = json.Marshal(bankState)
	}
	
	// Fix erc20 module - add native token configuration
	var erc20State map[string]interface{}
	if err := json.Unmarshal(genesis.AppState["erc20"], &erc20State); err == nil {
		// Add native token pair for amcc
		tokenPair := map[string]interface{}{
			"contract_owner": 1,
			"erc20_address": "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
			"denom": evmconfig.BaseDenom,
			"enabled": true,
		}
		erc20State["token_pairs"] = []interface{}{tokenPair}
		erc20State["native_precompiles"] = []string{"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"}
		genesis.AppState["erc20"], _ = json.Marshal(erc20State)
	}
	
	// Write back to file
	output, err := json.MarshalIndent(genesis, "", "  ")
	if err != nil {
		return fmt.Errorf("error marshaling genesis: %w", err)
	}
	
	if err := os.WriteFile(genesisPath, output, 0644); err != nil {
		return fmt.Errorf("error writing genesis file: %w", err)
	}
	
	fmt.Printf("✅ Successfully integrated genesis configuration fixes\n")
	fmt.Printf("Updated modules: evm, staking, mint, gov, bank\n")
	fmt.Printf("Set denomination to: %s\n", evmconfig.BaseDenom)

	return nil
}

// printInfo contains printing info
type printInfo struct {
	Moniker    string          `json:"moniker" yaml:"moniker"`
	ChainID    string          `json:"chain_id" yaml:"chain_id"`
	NodeID     string          `json:"node_id" yaml:"node_id"`
	GenTxsDir  string          `json:"gentxs_dir" yaml:"gentxs_dir"`
	AppMessage json.RawMessage `json:"app_message" yaml:"app_message"`
}

func newPrintInfo(moniker, chainID, nodeID, genTxsDir string, appMessage json.RawMessage) printInfo {
	return printInfo{
		Moniker:    moniker,
		ChainID:    chainID,
		NodeID:     nodeID,
		GenTxsDir:  genTxsDir,
		AppMessage: appMessage,
	}
}

func displayInfo(info printInfo) error {
	out, err := json.MarshalIndent(info, "", " ")
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(os.Stderr, "%s\n", string(sdk.MustSortJSON(out)))

	return err
}

// initializeNodeValidatorFilesFromMnemonic creates private validator, p2p keys and initial genesis file
func initializeNodeValidatorFilesFromMnemonic(config *cmtcfg.Config, mnemonic string) (nodeID string, valPubKey interface{}, err error) {
	if len(mnemonic) > 0 && !bip39.IsMnemonicValid(mnemonic) {
		return "", nil, fmt.Errorf("invalid mnemonic")
	}
	
	nodeKey, err := p2p.LoadOrGenNodeKey(config.NodeKeyFile())
	if err != nil {
		return nodeID, valPubKey, err
	}
	nodeID = string(nodeKey.ID())

	pvKeyFile := config.PrivValidatorKeyFile()
	pvStateFile := config.PrivValidatorStateFile()
	
	pv := privval.LoadOrGenFilePV(pvKeyFile, pvStateFile)
	valPubKey, _ = pv.GetPubKey()

	return nodeID, valPubKey, nil
}

// fileExists checks if file exists
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}