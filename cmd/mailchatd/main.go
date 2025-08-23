package main

import (
	"fmt"
	"os"

	"github.com/mail-coin/mailchatd/cmd/mailchatd/cmd"
	evmdconfig "github.com/mail-coin/mailchatd/cmd/mailchatd/config"
	"github.com/mail-coin/mailchatd"

	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func main() {
	setupSDKConfig()

	rootCmd := cmd.NewRootCmd()
	if err := svrcmd.Execute(rootCmd, evmd.AppName, evmd.DefaultNodeHome); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}

func setupSDKConfig() {
	config := sdk.GetConfig()
	evmdconfig.SetBech32Prefixes(config)
	config.Seal()
}
