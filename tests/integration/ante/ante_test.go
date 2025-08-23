package ante

import (
	"testing"

	"github.com/mail-chat-chain/mailchatd/tests/integration"
	"github.com/cosmos/evm/tests/integration/ante"
)

func TestAnte_Integration(t *testing.T) {
	ante.TestIntegrationAnteHandler(t, integration.CreateEvmd)
}
