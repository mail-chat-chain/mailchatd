package ante

import (
	"testing"

	"github.com/cosmos/evm/tests/integration/ante"
	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

func TestAnte_Integration(t *testing.T) {
	ante.TestIntegrationAnteHandler(t, integration.CreateEvmd)
}
