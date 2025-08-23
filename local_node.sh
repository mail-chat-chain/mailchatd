#!/bin/bash

CHAINID="${CHAIN_ID:-26000}"
MONIKER="localtestnet"
# Remember to change to other types of keyring like 'file' in-case exposing to outside world,
# otherwise your balance will be wiped quickly
# The keyring test does not require private key to steal tokens from you
KEYRING="test"
KEYALGO="eth_secp256k1"

LOGLEVEL="info"
# Set dedicated home directory for the mailchatd instance
CHAINDIR="$HOME/.mailchatd"

BASEFEE=10000000

# Path variables
CONFIG_TOML=$CHAINDIR/config/config.toml
APP_TOML=$CHAINDIR/config/app.toml
GENESIS=$CHAINDIR/config/genesis.json
TMP_GENESIS=$CHAINDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error (any non-zero exit code)
set -e

# Parse input flags
install=true
overwrite=""
BUILD_FOR_DEBUG=false

# Setup client configuration
setup_client_config() {
	echo "Setting up client configuration..."
	mailchatd config set client chain-id "$CHAINID" --home "$CHAINDIR"
	mailchatd config set client keyring-backend "$KEYRING" --home "$CHAINDIR"
}

# Setup accounts and keys
setup_accounts() {
	echo "Creating new accounts and keys..."
	
	# Define account names
	VAL_KEY="mykey"
	USER1_KEY="dev0"
	USER2_KEY="dev1"
	USER3_KEY="dev2"
	USER4_KEY="dev3"

	# Create new keys (this will generate random mnemonics)
	mailchatd keys add "$VAL_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
	mailchatd keys add "$USER1_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
	mailchatd keys add "$USER2_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
	mailchatd keys add "$USER3_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
	mailchatd keys add "$USER4_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"

	echo "New accounts created successfully!"
	echo "To view account addresses and mnemonics, use:"
	echo "  mailchatd keys list --home $CHAINDIR"
	echo "  mailchatd keys show <keyname> --home $CHAINDIR"
}

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
	-y)
		echo "Flag -y passed -> Overwriting the previous chain data."
		overwrite="y"
		shift # Move past the flag
		;;
	-n)
		echo "Flag -n passed -> Not overwriting the previous chain data."
		overwrite="n"
		shift # Move past the argument
		;;
	--no-install)
		echo "Flag --no-install passed -> Skipping installation of the mailchatd binary."
		install=false
		shift # Move past the flag
		;;
	--remote-debugging)
		echo "Flag --remote-debugging passed -> Building with remote debugging options."
		BUILD_FOR_DEBUG=true
		shift # Move past the flag
		;;
	*)
		echo "Unknown flag passed: $key -> Exiting script!"
		exit 1
		;;
	esac
done

if [[ $install == true ]]; then
	if [[ $BUILD_FOR_DEBUG == true ]]; then
		# for remote debugging the optimization should be disabled and the debug info should not be stripped
		make install COSMOS_BUILD_OPTIONS=nooptimization,nostrip
	else
		make install
	fi
fi

# User prompt if neither -y nor -n was passed as a flag
# and an existing local node configuration is found.
if [[ $overwrite = "" ]]; then
	if [ -d "$CHAINDIR" ]; then
		printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$CHAINDIR"
		echo "Overwrite the existing configuration and start a new local node? [y/n]"
		read -r overwrite
	else
		overwrite="y"
	fi
fi

# Initialize and configure the node
init_configure() {
	echo "Initializing and configuring the node..."
	# Initialize the chain
	mailchatd init "$MONIKER" --chain-id "$CHAINID" --home "$CHAINDIR"
}
# Configure genesis file parameters
update_genesis() {
	echo "Updating genesis file parameters..."

	# Change parameter token denominations to desired value
	jq '.app_state["staking"]["params"]["bond_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["evm"]["params"]["evm_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["mint"]["params"]["mint_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Add default token metadata to genesis
	jq '.app_state["bank"]["denom_metadata"]=[{"description":"The native staking token for mailchatd.","denom_units":[{"denom":"amcc","exponent":0,"aliases":["attomcc"]},{"denom":"mcc","exponent":18,"aliases":[]}],"base":"amcc","display":"mcc","name":"Mail Chat Coin","symbol":"MCC","uri":"","uri_hash":""}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Enable precompiles in EVM params
	jq '.app_state["evm"]["params"]["active_static_precompiles"]=["0x0000000000000000000000000000000000000100","0x0000000000000000000000000000000000000400","0x0000000000000000000000000000000000000800","0x0000000000000000000000000000000000000801","0x0000000000000000000000000000000000000802","0x0000000000000000000000000000000000000803","0x0000000000000000000000000000000000000804","0x0000000000000000000000000000000000000805", "0x0000000000000000000000000000000000000806", "0x0000000000000000000000000000000000000807"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Set EVM config
	jq '.app_state["evm"]["params"]["evm_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Enable native denomination as a token pair for STRv2
	jq '.app_state.erc20.native_precompiles=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state.erc20.token_pairs=[{contract_owner:1,erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",denom:"amcc",enabled:true}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Set gas limit in genesis
	jq '.consensus.params.block.max_gas="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
}

# Optimize network timing parameters
optimize_network_timing() {
	echo "Optimizing network timing parameters..."
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"
		sed -i '' 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "5s"/g' "$CONFIG_TOML"
	else
		sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
		sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
		sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
		sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
		sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"
		sed -i 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "5s"/g' "$CONFIG_TOML"
	fi

	# enable prometheus metrics and all APIs for dev node
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"
		sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time  = 1000000000000/g' "$APP_TOML"
		sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i '' 's/enable = false/enable = true/g' "$APP_TOML"
	else
		sed -i 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"
		sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
		sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i 's/enable = false/enable = true/g' "$APP_TOML"
	fi

	# Change proposal periods to pass within a reasonable time for local testing
	sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$GENESIS"
	sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$GENESIS"
	sed -i.bak 's/"expedited_voting_period": "86400s"/"expedited_voting_period": "15s"/g' "$GENESIS"

	# set custom pruning settings
	sed -i.bak 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
	sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "100"/g' "$APP_TOML"
	sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/g' "$APP_TOML"
}

# Allocate genesis accounts
allocate_accounts() {
	echo "Allocating genesis accounts..."
	# Allocate genesis accounts (cosmos formatted addresses)
	mailchatd genesis add-genesis-account "$VAL_KEY" 100000000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
	mailchatd genesis add-genesis-account "$USER1_KEY" 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
	mailchatd genesis add-genesis-account "$USER2_KEY" 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
	mailchatd genesis add-genesis-account "$USER3_KEY" 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
	mailchatd genesis add-genesis-account "$USER4_KEY" 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
}

# Setup validator and finalize genesis
setup_validator() {
	echo "Setting up validator and finalizing genesis..."
	# Sign genesis transaction
	mailchatd genesis gentx "$VAL_KEY" 1000000000000000000000amcc --gas-prices ${BASEFEE}amcc --keyring-backend "$KEYRING" --chain-id "$CHAINID" --home "$CHAINDIR"
	## In case you want to create multiple validators at genesis
	## 1. Back to `mailchatd keys add` step, init more keys
	## 2. Back to `mailchatd add-genesis-account` step, add balance for those
	## 3. Clone this ~/.mailchatd home directory into some others, let's say `~/.clonedMailchatd`
	## 4. Run `gentx` in each of those folders
	## 5. Copy the `gentx-*` folders under `~/.clonedMailchatd/config/gentx/` folders into the original `~/.mailchatd/config/gentx`

	# Collect genesis tx
	mailchatd genesis collect-gentxs --home "$CHAINDIR"

	# Run this to ensure everything worked and that the genesis file is setup correctly
	mailchatd genesis validate-genesis --home "$CHAINDIR"

	if [[ $1 == "pending" ]]; then
		echo "pending mode is on, please wait for the first block committed."
	fi
}

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	rm -rf "$CHAINDIR"

	# Run setup functions in sequence
	setup_client_config
	init_configure
	# update_genesis
	# optimize_network_timing
	setup_accounts
	allocate_accounts
	setup_validator
fi

# Start the node (chain-id is now auto-configured during init)
mailchatd start \
	--log_level $LOGLEVEL \
	--minimum-gas-prices=0.0001amcc \
	--home "$CHAINDIR" \
	--json-rpc.api eth,txpool,personal,net,debug,web3 \
	--chain-id "$CHAINID"
