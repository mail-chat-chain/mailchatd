// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./SafeAccount.sol";
import "./IEntryPoint.sol";

/**
 * SafeAccountFactory - Secure factory for creating SafeAccount instances.
 * This factory uses CREATE2 to deploy accounts with deterministic addresses,
 * optimized for bundler-free Account Abstraction operations with enhanced security.
 */
contract SafeAccountFactory {
    SafeAccount public immutable accountImplementation;

    event AccountCreated(address indexed account, address indexed owner, uint256 salt);

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new SafeAccount(_entryPoint);
    }

    /**
     * Create an account, and return its address.
     * Returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation.
     * @param owner - the owner of the account to be created
     * @param salt - a salt, which can be changed to create multiple accounts with the same owner
     */
    function createAccount(address owner, uint256 salt) public returns (SafeAccount ret) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SafeAccount(payable(addr));
        }
        ret = SafeAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(SafeAccount.initialize, (owner))
                )
            )
        );
        emit AccountCreated(address(ret), owner, salt);
    }

    /**
     * Calculate the counterfactual address of this account as it would be returned by createAccount()
     * @param owner - the owner of the account to be created
     * @param salt - a salt, which can be changed to create multiple accounts with the same owner
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        return
            Clones.predictDeterministicAddress(
                address(accountImplementation),
                _getCloneSalt(owner, salt),
                address(this)
            );
    }

    /**
     * Get the salt used for CREATE2 deployment
     * @param owner - the owner of the account
     * @param salt - the user-provided salt
     */
    function _getCloneSalt(address owner, uint256 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}

/**
 * Minimal proxy library for efficient account deployment
 */
library Clones {
    /**
     * Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3000000000000000000000000000000000000)
            let hash := keccak256(ptr, 0x37)
            ptr := mload(0x40)
            mstore(ptr, 0xff)
            mstore(add(ptr, 0x01), shl(0x60, deployer))
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), hash)
            predicted := keccak256(ptr, 0x55)
        }
    }
}

/**
 * ERC1967 Proxy implementation for upgradeable accounts
 */
contract ERC1967Proxy {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event Upgraded(address indexed implementation);

    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        if (data.length > 0 || forceCall) {
            (bool success, ) = newImplementation.delegatecall(data);
            require(success, "ERC1967Proxy: delegatecall failed");
        }
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "ERC1967: new implementation is not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    fallback() external payable {
        address impl = _implementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}