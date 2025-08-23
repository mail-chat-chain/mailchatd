package ante

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/mail-chat-chain/mailchatd/tests/integration"
	"github.com/cosmos/evm/tests/integration/ante"
)

func TestEvmUnitAnteTestSuite(t *testing.T) {
	suite.Run(t, ante.NewEvmUnitAnteTestSuite(integration.CreateEvmd))
}
