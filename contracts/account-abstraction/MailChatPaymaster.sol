// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IEntryPoint.sol";
import "./UserOperation.sol";
import "./Helpers.sol";

/**
 * MailChat Chain's paymaster contract for sponsoring gas payments.
 * This paymaster can sponsor transactions for whitelisted users or based on
 * custom logic, optimized for the bundler-free Account Abstraction system.
 * Features include whitelist management, gas limits, and flexible sponsorship rules.
 */
contract MailChatPaymaster is IPaymaster {
    using UserOperationLib for UserOperation;

    IEntryPoint public immutable entryPoint;
    address public owner;
    
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public sponsoredGas;
    
    uint256 public maxSponsoredGas = 1000000; // Maximum gas to sponsor per transaction
    
    event PaymasterDeposit(uint256 amount);
    event PaymasterWithdraw(uint256 amount, address to);
    event UserOpSponsored(address indexed user, uint256 actualGasCost);
    event WhitelistUpdated(address indexed user, bool whitelisted);

    modifier onlyOwner() {
        require(msg.sender == owner, "MailChatPaymaster: caller is not the owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "MailChatPaymaster: caller is not EntryPoint");
        _;
    }

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        owner = msg.sender;
    }

    /**
     * Transfer ownership of the paymaster.
     * @param newOwner - the new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MailChatPaymaster: new owner is zero address");
        owner = newOwner;
    }

    /**
     * Add or remove a user from the whitelist.
     * @param user - the user address
     * @param whitelisted - whether the user should be whitelisted
     */
    function setWhitelist(address user, bool whitelisted) external onlyOwner {
        whitelist[user] = whitelisted;
        emit WhitelistUpdated(user, whitelisted);
    }

    /**
     * Set the maximum sponsored gas per transaction.
     * @param _maxSponsoredGas - the maximum gas amount
     */
    function setMaxSponsoredGas(uint256 _maxSponsoredGas) external onlyOwner {
        maxSponsoredGas = _maxSponsoredGas;
    }

    /**
     * Validate a paymaster user operation.
     * @param userOp - the user operation to validate.
     * @param userOpHash - hash of the user's request data.
     * @param maxCost - the maximum cost of this transaction (based on maximum gas and gas price from userOp)
     * @return context - value to send to a postOp. zero length to signify postOp is not required.
     * @return validationData - signature and time-range of this operation.
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external view override onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        // Check if user is whitelisted
        if (!whitelist[userOp.sender]) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }
        
        // Check if we have enough balance to cover the cost
        if (entryPoint.balanceOf(address(this)) < maxCost) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }
        
        // Check gas limits
        uint256 gasLimit = userOp.gasLimit();
        if (gasLimit > maxSponsoredGas) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }
        
        // Encode context for postOp
        context = abi.encode(userOp.sender, maxCost, userOpHash);
        
        // Return success
        validationData = 0;
    }

    /**
     * Post-operation handler.
     * @param mode - enum with the following options:
     *                  opSucceeded - user operation succeeded.
     *                  opReverted - user operation reverted. still has to pay for gas.
     *                  postOpReverted - user operation succeeded, but caused postOp to revert.
     * @param context - the context value returned by validatePaymasterUserOp
     * @param actualGasCost - actual gas used so far (without this postOp call).
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override onlyEntryPoint {
        if (context.length == 0) {
            return; // No context, nothing to do
        }
        
        (address sender, uint256 maxCost, bytes32 userOpHash) = abi.decode(
            context, 
            (address, uint256, bytes32)
        );
        
        // Update sponsored gas tracking
        sponsoredGas[sender] += actualGasCost;
        
        emit UserOpSponsored(sender, actualGasCost);
        
        // In case of revert, we might want to implement penalty logic
        if (mode == PostOpMode.opReverted) {
            // Handle reverted operation - could implement penalty logic here
        }
    }

    /**
     * Deposit funds to the EntryPoint for this paymaster.
     */
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
        emit PaymasterDeposit(msg.value);
    }

    /**
     * Withdraw funds from the EntryPoint.
     * @param to - target to send to
     * @param amount - to withdraw
     */
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
        emit PaymasterWithdraw(amount, to);
    }

    /**
     * Get the deposit balance for this paymaster.
     */
    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * Get sponsored gas amount for a user.
     * @param user - the user address
     */
    function getSponsoredGas(address user) external view returns (uint256) {
        return sponsoredGas[user];
    }

    /**
     * Check if a user is whitelisted.
     * @param user - the user address
     */
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user];
    }

    /**
     * Allow the paymaster to receive ETH directly.
     */
    receive() external payable {
        deposit();
    }
}