package slashing

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/cosmos/evm/tests/integration/precompiles/slashing"
	"github.com/mail-chat-chain/mailchatd/tests/integration"
)

func TestSlashingPrecompileTestSuite(t *testing.T) {
	s := slashing.NewPrecompileTestSuite(integration.CreateEvmd)
	suite.Run(t, s)
}

func TestStakingPrecompileIntegrationTestSuite(t *testing.T) {
	slashing.TestPrecompileIntegrationTestSuite(t, integration.CreateEvmd)
}
