package staking

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/mail-coin/mailchatd/tests/integration"
	"github.com/cosmos/evm/tests/integration/precompiles/staking"
)

func TestStakingPrecompileTestSuite(t *testing.T) {
	s := staking.NewPrecompileTestSuite(integration.CreateEvmd)
	suite.Run(t, s)
}

func TestStakingPrecompileIntegrationTestSuite(t *testing.T) {
	staking.TestPrecompileIntegrationTestSuite(t, integration.CreateEvmd)
}
