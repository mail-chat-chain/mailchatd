require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: {
    version: "0.8.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./account-abstraction",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};