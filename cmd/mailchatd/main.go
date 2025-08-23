package main

import (
	"fmt"
	"os"

	"github.com/mail-chat-chain/mailchatd/cmd/mailchatd/cmd"
	"github.com/mail-chat-chain/mailchatd/config"
	evmdconfig "github.com/mail-chat-chain/mailchatd/config"

	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func main() {
	setupSDKConfig()

	rootCmd := cmd.NewRootCmd()
	if err := svrcmd.Execute(rootCmd, config.AppName, evmdconfig.MustGetDefaultNodeHome()); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}

func setupSDKConfig() {
	config := sdk.GetConfig()
	evmdconfig.SetBech32Prefixes(config)
	config.Seal()
}
