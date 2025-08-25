// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./OptimizedEntryPoint.sol";
import "./UserOperation.sol";

/**
 * @title DirectUserInterface - 用户可以直接交互的接口合约
 * @dev 完全移除 bundler，用户直接与合约交互
 */
contract DirectUserInterface {
    OptimizedEntryPoint public immutable entryPoint;
    
    // 用户操作队列（替代 bundler 内存池）
    struct QueuedOperation {
        UserOperation userOp;
        address submitter;
        uint256 timestamp;
        uint256 gasTipReward; // 给执行者的奖励
    }
    
    mapping(bytes32 => QueuedOperation) public queuedOps;
    bytes32[] public executionQueue;
    
    // 执行奖励池
    mapping(address => uint256) public executorRewards;
    
    event UserOperationQueued(bytes32 indexed hash, address indexed sender, uint256 gasTipReward);
    event BatchExecuted(address indexed executor, uint256 opsCount, uint256 reward);

    constructor(address _entryPoint) {
        entryPoint = OptimizedEntryPoint(_entryPoint);
    }

    /**
     * @dev 用户直接提交操作到队列
     * 支付小额 tip 激励他人执行
     */
    function submitUserOperation(
        UserOperation calldata userOp,
        uint256 gasTipReward
    ) external payable returns (bytes32 userOpHash) {
        require(msg.value >= gasTipReward, "Insufficient tip payment");
        
        // 使用预编译获取哈希
        userOpHash = entryPoint.getUserOpHash(userOp);
        
        // 添加到执行队列
        queuedOps[userOpHash] = QueuedOperation({
            userOp: userOp,
            submitter: msg.sender,
            timestamp: block.timestamp,
            gasTipReward: gasTipReward
        });
        
        executionQueue.push(userOpHash);
        
        emit UserOperationQueued(userOpHash, userOp.sender, gasTipReward);
        return userOpHash;
    }

    /**
     * @dev 任何人都可以执行队列中的操作并获得奖励
     * 这替代了 bundler 的经济激励机制
     */
    function executeQueuedOperations(uint256 maxOps) external {
        require(maxOps > 0 && maxOps <= 10, "Invalid batch size");
        
        uint256 opsToExecute = maxOps;
        if (opsToExecute > executionQueue.length) {
            opsToExecute = executionQueue.length;
        }
        
        UserOperation[] memory ops = new UserOperation[](opsToExecute);
        uint256 totalReward = 0;
        
        // 从队列中取出操作
        for (uint256 i = 0; i < opsToExecute; i++) {
            bytes32 hash = executionQueue[i];
            QueuedOperation memory queuedOp = queuedOps[hash];
            
            ops[i] = queuedOp.userOp;
            totalReward += queuedOp.gasTipReward;
            
            // 清理
            delete queuedOps[hash];
        }
        
        // 移除已处理的操作
        for (uint256 i = 0; i < opsToExecute; i++) {
            executionQueue[i] = executionQueue[executionQueue.length - 1 - i];
        }
        for (uint256 i = 0; i < opsToExecute; i++) {
            executionQueue.pop();
        }
        
        // 执行批量操作
        entryPoint.handleOps(ops, payable(msg.sender));
        
        // 支付执行奖励
        if (totalReward > 0) {
            executorRewards[msg.sender] += totalReward;
            payable(msg.sender).transfer(totalReward);
        }
        
        emit BatchExecuted(msg.sender, opsToExecute, totalReward);
    }

    /**
     * @dev 估算用户操作的 Gas（使用预编译）
     */
    function estimateUserOperationGas(UserOperation calldata userOp) 
        external view returns (
            uint256 callGasLimit,
            uint256 verificationGasLimit, 
            uint256 preVerificationGas
        ) {
        // 调用 OptimizedEntryPoint 的模拟方法
        OptimizedEntryPoint.ValidationResult memory result = entryPoint.simulateValidation(userOp);
        
        return (200000, 100000, 50000); // 简化返回
    }

    /**
     * @dev 获取用户操作状态
     */
    function getUserOperationStatus(bytes32 userOpHash) 
        external view returns (
            bool queued,
            bool executed,
            uint256 queuePosition
        ) {
        
        QueuedOperation memory queuedOp = queuedOps[userOpHash];
        if (queuedOp.timestamp > 0) {
            // 在队列中，找到位置
            for (uint256 i = 0; i < executionQueue.length; i++) {
                if (executionQueue[i] == userOpHash) {
                    return (true, false, i);
                }
            }
        }
        
        // TODO: 检查是否已执行（查询 EntryPoint 事件）
        return (false, false, 0);
    }
    
    /**
     * @dev 获取队列状态
     */
    function getQueueInfo() external view returns (
        uint256 queueLength,
        uint256 totalRewardPool
    ) {
        queueLength = executionQueue.length;
        totalRewardPool = address(this).balance;
    }

    /**
     * @dev 紧急情况下，用户可以取消自己的操作
     */
    function cancelUserOperation(bytes32 userOpHash) external {
        QueuedOperation memory queuedOp = queuedOps[userOpHash];
        require(queuedOp.submitter == msg.sender, "Not your operation");
        require(block.timestamp > queuedOp.timestamp + 300, "Too early to cancel"); // 5分钟后可取消
        
        // 退还 tip
        payable(msg.sender).transfer(queuedOp.gasTipReward);
        
        // 从队列中移除
        delete queuedOps[userOpHash];
        // TODO: 从 executionQueue 数组中移除
    }
}