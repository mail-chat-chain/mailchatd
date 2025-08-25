// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * Essential helper functions for bundler-free EIP-4337 implementation
 * Only contains functions that are actually used by the system
 */
library Helpers {
    /**
     * Parse validation data into components
     * Used by EIP-4337 standard for time-based validation
     */
    function parseValidationData(uint256 validationData)
        internal
        pure
        returns (uint256 validAfter, uint256 validUntil, bool sigFailed)
    {
        sigFailed = (validationData & 1) != 0;
        validUntil = uint48(validationData >> 160);
        if (validUntil == 0) {
            validUntil = type(uint48).max;
        }
        validAfter = uint48(validationData >> 208);
    }

    /**
     * Pack validation data from components
     * Used by EIP-4337 standard for time-based validation
     */
    function packValidationData(
        bool sigFailed,
        uint256 validAfter,
        uint256 validUntil
    ) internal pure returns (uint256) {
        return (sigFailed ? 1 : 0) | (validAfter << 208) | (validUntil << 160);
    }

    /**
     * Extract r, s, v from ECDSA signature
     * Used internally by recoverAddress function
     */
    function extractSignature(bytes memory signature)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(signature.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        // Handle legacy signature format
        if (v < 27) {
            v += 27;
        }
    }

    /**
     * Recover address from ECDSA signature
     * Used by SafeAccount for signature validation
     */
    function recoverAddress(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = extractSignature(signature);
        return ecrecover(hash, v, r, s);
    }

    /**
     * Get the CREATE2 address for an account
     * Used by SafeAccountFactory for deterministic address calculation
     */
    function getCreate2Address(
        address factory,
        bytes memory initCode,
        bytes32 salt
    ) internal pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), factory, salt, keccak256(initCode))
        );
        return address(uint160(uint256(hash)));
    }
}