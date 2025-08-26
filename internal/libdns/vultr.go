//go:build libdns_vultr
// +build libdns_vultr

package libdns

import (
	"github.com/libdns/vultr"
	"github.com/mail-chat-chain/mailchatd/framework/config"
	"github.com/mail-chat-chain/mailchatd/framework/module"
)

func init() {
	module.Register("libdns.vultr", func(modName, instName string, _, _ []string) (module.Module, error) {
		p := vultr.Provider{}
		return &ProviderModule{
			RecordDeleter:  &p,
			RecordAppender: &p,
			setConfig: func(c *config.Map) {
				c.String("api_token", false, false, "", &p.APIToken)
			},
			instName: instName,
			modName:  modName,
		}, nil
	})
}
