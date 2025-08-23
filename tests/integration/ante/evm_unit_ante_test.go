package ante

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/cosmos/evm/tests/integration/ante"
	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

func TestEvmUnitAnteTestSuite(t *testing.T) {
	suite.Run(t, ante.NewEvmUnitAnteTestSuite(integration.CreateEvmd))
}
