// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * User Operation struct
 * @param sender - The account making the operation
 * @param nonce - Unique value the entity uses to identify UserOperation
 * @param initCode - The initCode to use to create the account (needed if account not yet on-chain and needs to be created)
 * @param callData - The data to pass to the sender during the main execution call
 * @param callGasLimit - The amount of gas to allocate the main execution call
 * @param verificationGasLimit - The amount of gas to allocate for the verification step
 * @param preVerificationGas - The amount of gas to pay for to compensate the bundler for pre-verification execution and calldata
 * @param maxFeePerGas - Maximum fee per gas (similar to EIP-1559 max_fee_per_gas)
 * @param maxPriorityFeePerGas - Maximum priority fee per gas (similar to EIP-1559 max_priority_fee_per_gas)
 * @param paymasterAndData - Address of paymaster sponsoring the transaction, followed by extra data to send to the paymaster (can be empty)
 * @param signature - Data passed into the account along with the nonce during the verification step
 */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

/**
 * Utility functions helpful when working with UserOperation structs.
 */
library UserOperationLib {
    /**
     * Get sender from user operation data.
     * @param userOp - The user operation data.
     */
    function getSender(UserOperation calldata userOp) 
        internal 
        pure 
        returns (address) 
    {
        address data;
        //read sender from userOp, which is first userOp member (saves 800 gas...)
        assembly {
            data := calldataload(userOp)
        }
        return address(uint160(data));
    }

    /**
     * Get the paymaster address from paymasterAndData.
     * @param userOp - The user operation data.
     */
    function paymaster(UserOperation calldata userOp) 
        internal 
        pure 
        returns (address) 
    {
        if (userOp.paymasterAndData.length < 20) {
            return address(0);
        }
        return address(bytes20(userOp.paymasterAndData[:20]));
    }

    /**
     * Relayer/bundler might submit the UserOperation with higher gas prices 
     * than the user specified, to guarantee it will be mined.
     * This method returns the gas price this UserOperation has agreed to pay.
     * gasPrice (and baseFee) are set by the relayer for efficiency.
     * @param userOp - The user operation data.
     */
    function gasPrice(UserOperation calldata userOp) 
        internal 
        view 
        returns (uint256) 
    {
        unchecked {
            uint256 maxFeePerGas = userOp.maxFeePerGas;
            uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
            if (maxFeePerGas == maxPriorityFeePerGas) {
                //legacy mode (for networks that don't support basefee opcode)
                return maxFeePerGas;
            }
            return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
        }
    }

    /**
     * Pack the user operation data into bytes for hashing.
     * @param userOp - The user operation data.
     */
    function pack(UserOperation calldata userOp) 
        internal 
        pure 
        returns (bytes memory) 
    {
        return abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.initCode),
            keccak256(userOp.callData),
            userOp.callGasLimit,
            userOp.verificationGasLimit,
            userOp.preVerificationGas,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            keccak256(userOp.paymasterAndData)
        );
    }

    /**
     * Hash the user operation data.
     * @param userOp - The user operation data.
     */
    function hash(UserOperation calldata userOp) 
        internal 
        pure 
        returns (bytes32) 
    {
        return keccak256(pack(userOp));
    }

    /**
     * Get the gas limit for this UserOperation.
     * @param userOp - The user operation data.
     */
    function gasLimit(UserOperation calldata userOp) 
        internal 
        pure 
        returns (uint256) 
    {
        unchecked {
            return userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        }
    }

    /**
     * Get the maximum gas cost for this UserOperation (assuming all gas is used).
     * @param userOp - The user operation data.
     */
    function requiredPrefund(UserOperation calldata userOp) 
        internal 
        view 
        returns (uint256) 
    {
        unchecked {
            uint256 requiredGas = gasLimit(userOp);
            return requiredGas * gasPrice(userOp);
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}