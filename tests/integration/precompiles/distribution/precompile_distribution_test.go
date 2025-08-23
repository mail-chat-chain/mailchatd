package distribution

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/cosmos/evm/tests/integration/precompiles/distribution"
	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

func TestDistributionPrecompileTestSuite(t *testing.T) {
	s := distribution.NewPrecompileTestSuite(integration.CreateEvmd)
	suite.Run(t, s)
}

func TestDistributionPrecompileIntegrationTestSuite(t *testing.T) {
	distribution.TestPrecompileIntegrationTestSuite(t, integration.CreateEvmd)
}
