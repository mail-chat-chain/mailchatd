package main

import (
	"fmt"
	"os"

	app "github.com/mail-chat-chain/mailchatd/app"
	"github.com/mail-chat-chain/mailchatd/cmd/mailchatd/cmd"
	evmdconfig "github.com/mail-chat-chain/mailchatd/cmd/mailchatd/config"

	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func main() {
	setupSDKConfig()

	rootCmd := cmd.NewRootCmd()
	if err := svrcmd.Execute(rootCmd, app.AppName, evmdconfig.MustGetDefaultNodeHome()); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}

func setupSDKConfig() {
	config := sdk.GetConfig()
	evmdconfig.SetBech32Prefixes(config)
	config.Seal()
}
