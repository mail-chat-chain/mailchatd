package gov

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/cosmos/evm/tests/integration/precompiles/gov"
	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

func TestGovPrecompileTestSuite(t *testing.T) {
	s := gov.NewPrecompileTestSuite(integration.CreateEvmd)
	suite.Run(t, s)
}

func TestGovPrecompileIntegrationTestSuite(t *testing.T) {
	gov.TestPrecompileIntegrationTestSuite(t, integration.CreateEvmd)
}
