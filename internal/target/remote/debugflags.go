//go:build debugflags
// +build debugflags

/*
MailChat - Composable all-in-one email server.
Copyright © 2019-2020 Max Mazurov <fox.cpp@disroot.org>, MailChat contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package remote

// mailchatcli "github.com/mail-chat-chain/mailchatd/internal/cli" // Removed - now using Cosmos SDK CLI

func init() {
	// Note: Debug flags were previously added via mailchatcli.AddGlobalFlag
	// This functionality is now handled by Cosmos SDK's CLI system
	// TODO: Migrate to Cosmos SDK flag system if needed
	
	// mailchatcli.AddGlobalFlag(&cli.StringFlag{
	// 	Name:        "debug.smtpport",
	// 	Usage:       "SMTP port to use for connections in tests",
	// 	Destination: &smtpPort,
	// })
}
