# MailChat Chain 完整技术文档

## 目录

1. [项目概述](#项目概述)
2. [快速开始](#快速开始)
3. [系统架构](#系统架构)
4. [配置管理](#配置管理)
5. [邮件服务器配置](#邮件服务器配置)
6. [节点运维](#节点运维)
7. [质押与治理](#质押与治理)
8. [跨链桥（IBC）](#跨链桥ibc)
9. [开发指南](#开发指南)
10. [故障排除](#故障排除)
11. [Account Abstraction (无 Bundler)](#account-abstraction-无-bundler)
12. [参考资源](#参考资源)

---

## 项目概述

MailChat Chain 是一个基于 Cosmos SDK v0.53.4 和 Ethereum Virtual Machine (EVM) 的高性能区块链平台，结合了 Cosmos 生态的模块化架构与以太坊的智能合约兼容性。

### 核心特性

| 特性 | 描述 |
|-----|------|
| **EVM 兼容** | 完全支持 Solidity 智能合约，兼容 Web3 工具链 |
| **IBC 协议** | 原生支持跨链通信，可与 Cosmos 生态互操作 |
| **高性能** | 基于 Tendermint BFT 共识，支持秒级确认 |
| **模块化** | 灵活的模块系统，易于定制和扩展 |
| **双重接口** | 同时支持 Cosmos SDK 和 Ethereum JSON-RPC |
| **🆕 无 Bundler AA** | 世界首个无 bundler 的 Account Abstraction 实现 |

### 技术规格

```yaml
区块链参数:
  共识机制: Tendermint BFT
  出块时间: 1-5秒（可配置）
  链ID: mailchatd_26000 (生产网络)
  EVM链ID: 26000
  
代币经济:
  原生代币: MCC
  最小单位: amcc (1 MCC = 10^18 amcc)
  精度: 18位小数
  初始通胀率: 13%
  
性能指标:
  TPS: ~1000 (取决于硬件和网络)
  最终性: 即时（单块确认）
  Gas限制: 10,000,000 per block
```

---

## 快速开始

### 环境要求

```bash
# 系统要求
- 操作系统: Ubuntu 20.04+ / macOS 12+
- CPU: 4核心以上
- 内存: 8GB以上
- 存储: 100GB SSD
- Go版本: 1.23.8+

# 依赖工具
- Git
- Make
- jq
- curl
```

### 安装步骤

#### 1. 克隆并构建

```bash
# 克隆仓库
git clone https://github.com/mail-chat-chain/mailchatd.git
cd mailchatd

# 构建二进制文件
make build

# 验证安装
./mailchatd version
# 输出: 0.1.0
```

#### 2. 初始化节点

```bash
# 设置环境变量
export CHAINID="mailchatd_26000"
export MONIKER="my-node"
export CHAINDIR="$HOME/.mailchatd"

# 初始化节点
./mailchatd init $MONIKER --chain-id $CHAINID --home $CHAINDIR

# 创建账户
./mailchatd keys add validator --keyring-backend test --algo eth_secp256k1
./mailchatd keys add user1 --keyring-backend test --algo eth_secp256k1
```

#### 3. 启动本地测试网

```bash
# 快速启动（重置数据）
./local_node.sh -y

# 保留现有数据启动
./local_node.sh -n

# 带调试模式
./local_node.sh --remote-debugging
```

### 连接 MetaMask

1. 打开 MetaMask，点击网络下拉菜单
2. 选择"添加网络"
3. 填入以下信息：

```javascript
{
  "网络名称": "MailChat Local",
  "RPC URL": "http://localhost:8545",
  "链 ID": 26000,
  "货币符号": "MCC",
  "区块浏览器": "https://explorer.blocksout.com" // 官方 BlocksOut 前端
}
```

4. 导入测试账户（从 `mailchatd keys show --address` 获取）

### 网络环境配置

| 环境 | 网络名称 | RPC URL | 链ID | 货币符号 | 区块浏览器 |
|------|----------|---------|------|----------|-------------|
| **本地开发** | MailChat Local | http://localhost:8545 | 26000 | MCC | http://localhost:8080 |
| **生产网络** | MailChat Chain | http://129.226.150.87:8545 | 26000 | MCC | http://129.226.150.87:8080 |
| **测试网** | MailChat Testnet | https://testnet-rpc.mailchat.io | 262144 | MCC | https://testnet.explorer.blocksout.com |
| **主网** | MailChat Mainnet | https://rpc.mailchat.io | 262144 | MCC | https://explorer.blocksout.com |

### 生产网络详情

**MailChat Chain 生产网络** (mailchatd_26000) 由3个验证人节点组成：

| 服务器 | 主机名 | 公网IP | 验证人地址 | 投票权 |
|--------|--------|--------|-----------|--------|
| tx-htx-1 | VM-16-13-debian | 129.226.150.87 | F8A114035A833756CE0CE92193DED4380BD545CA | 1000 |
| tx-htx-2 | VM-16-4-debian | 43.134.188.44 | 370C1E79C75C7CCC6770EFCAD4E3AFA28A7A4E4B | 1000 |
| tx-htx-3 | VM-0-10-debian | 43.156.5.216 | 0004921274C361C06436F14EE788B7DC62D6D8C4 | 1000 |

**网络参数:**
- **链ID**: `mailchatd_26000`
- **EVM链ID**: `26000`
- **共识**: Tendermint BFT (3/3 验证人)
- **RPC端点**: `http://129.226.150.87:8545` (主节点)
- **区块浏览器**: `http://129.226.150.87:8080`

**服务分布:**
- **tx-htx-1**: 主服务节点 + 验证人 (RPC, 区块浏览器, SMTP/IMAP)
- **tx-htx-2**: 验证人节点
- **tx-htx-3**: 验证人节点

详细部署信息请参考 [DEPLOYMENT.md](DEPLOYMENT.md)。

> **注意**: 生产网络使用实际的腾讯云服务器，主网和测试网使用官方 BlocksOut 前端页面作为区块链浏览器界面

---

## 系统架构

### 模块架构图

```
┌─────────────────────────────────────────────────┐
│                   应用层 (App)                   │
├─────────────────────────────────────────────────┤
│   EVM 模块    │   IBC 模块   │  Cosmos 模块     │
│  ┌─────────┐  │ ┌──────────┐ │ ┌────────────┐  │
│  │   VM    │  │ │ Transfer │ │ │  Staking   │  │
│  │  ERC20  │  │ │ Callbacks│ │ │   Gov      │  │
│  │FeeMarket│  │ │   ICS20  │ │ │   Mint     │  │
│  └─────────┘  │ └──────────┘ │ └────────────┘  │
├─────────────────────────────────────────────────┤
│              Tendermint 共识层                   │
├─────────────────────────────────────────────────┤
│                 P2P 网络层                       │
└─────────────────────────────────────────────────┘
```

### 核心模块详解

#### 1. EVM 相关模块

| 模块 | 功能 | 关键特性 |
|------|------|----------|
| **x/vm** | EVM 执行环境 | - Ethereum 1:1 兼容<br>- 支持所有 EVM 操作码<br>- 自定义预编译合约 |
| **x/erc20** | 代币桥接 | - 原生代币 ↔ ERC20 转换<br>- 自动代币对创建<br>- IBC 代币映射 |
| **x/feemarket** | 动态费用 | - EIP-1559 实现<br>- 基础费用自动调整<br>- 优先费用竞价 |
| **x/precisebank** | 精确计算 | - 18位小数精度<br>- 防止精度损失<br>- 批量转账优化 |

#### 2. 预编译合约

MailChat Chain 提供丰富的预编译合约，实现 EVM 与 Cosmos SDK 原生功能的深度集成：

| 地址 | 模块 | 功能描述 | Gas消耗 |
|------|------|----------|---------|
| `0x0000000000000000000000000000000000000100` | **P256验证** | secp256r1 椭圆曲线签名验证 | 基础: 3450 gas |
| `0x0000000000000000000000000000000000000400` | **Bech32编码** | Cosmos地址编解码转换 | 基础: 6000 gas |
| `0x0000000000000000000000000000000000000800` | **Staking质押** | 委托、解绑、重新委托操作 | 200000-300000 gas |
| `0x0000000000000000000000000000000000000801` | **Distribution分配** | 奖励提取和分配管理 | 150000-250000 gas |
| `0x0000000000000000000000000000000000000802` | **ICS20跨链** | IBC 代币跨链转账 | 300000-500000 gas |
| `0x0000000000000000000000000000000000000803` | **Governance治理** | 链上提案创建与投票 | 100000-400000 gas |
| `0x0000000000000000000000000000000000000804` | **Slashing惩罚** | 验证人惩罚和监禁管理 | 50000-150000 gas |
| `0x0000000000000000000000000000000000000805` | **Bank银行** | 原生代币转账操作 | 50000-100000 gas |
| `0x0000000000000000000000000000000000000806` | **ERC20模块** | ERC20代币与原生代币桥接 | 100000-200000 gas |
| `0x0000000000000000000000000000000000000807` | **WERC20包装** | 包装代币功能 | 80000-150000 gas |
| `0x0000000000000000000000000000000000000808` | **Account Abstraction** | 🆕 无Bundler账户抽象 | 10000-80000 gas |

#### 预编译合约使用方法

**1. 接口定义方式**

```solidity
// Staking 预编译接口
interface IStaking {
    function delegate(
        address delegator,
        string memory validator,
        uint256 amount
    ) external returns (bool);
    
    function undelegate(
        address delegator,
        string memory validator,
        uint256 amount
    ) external returns (uint256);
    
    function redelegate(
        address delegator,
        string memory srcValidator,
        string memory dstValidator,
        uint256 amount
    ) external returns (uint256);
}

// Governance 预编译接口
interface IGovernance {
    function submitProposal(
        string memory title,
        string memory description,
        uint256 initialDeposit
    ) external returns (uint64);
    
    function vote(
        uint64 proposalId,
        uint8 option
    ) external returns (bool);
    
    function deposit(
        uint64 proposalId,
        uint256 amount
    ) external returns (bool);
}

// ICS20 跨链转账接口
interface IICS20 {
    function transfer(
        string memory sourcePort,
        string memory sourceChannel,
        string memory denom,
        uint256 amount,
        address sender,
        string memory receiver,
        RevisionHeight memory revisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external returns (bool);
    
    struct RevisionHeight {
        uint64 revisionNumber;
        uint64 revisionHeight;
    }
}
```

**2. 低级别调用方式**

```solidity
// 直接调用预编译合约
contract PrecompileExample {
    function callPrecompile(
        address precompileAddr,
        bytes memory data
    ) external returns (bytes memory result) {
        (bool success, bytes memory returnData) = precompileAddr.call(data);
        require(success, "Precompile call failed");
        return returnData;
    }
    
    // Account Abstraction 方法选择器示例
    function validateUserOp(bytes memory userOpData) external {
        bytes memory data = abi.encodePacked(bytes4(0x00000001), userOpData);
        this.callPrecompile(0x0000000000000000000000000000000000000808, data);
    }
}
```

**3. 方法选择器参考**

Account Abstraction 预编译 (`0x808`) 方法：

```solidity
// 方法选择器映射
bytes4 constant VALIDATE_USER_OP = 0x00000001;     // validateUserOp - 50000 gas
bytes4 constant GET_USER_OP_HASH = 0x00000002;     // getUserOpHash - 10000 gas
bytes4 constant CREATE_ACCOUNT = 0x00000003;       // createAccount - 60000 gas
bytes4 constant GET_NONCE = 0x00000004;            // getNonce - 5000 gas
bytes4 constant VALIDATE_PAYMASTER = 0x00000005;   // validatePaymaster - 30000 gas
bytes4 constant CALCULATE_PREFUND = 0x00000006;    // calculatePrefund - 15000 gas
bytes4 constant AGGREGATE_SIGNATURES = 0x00000007; // aggregateSignatures - 80000 gas
bytes4 constant SIMULATE_VALIDATION = 0x00000008;  // simulateValidation - 40000 gas
```

---

## 配置管理

### 链参数配置层级

```
配置优先级（从高到低）：
1. 命令行参数
2. 环境变量
3. 配置文件 (app.toml, config.toml)
4. Genesis.json
5. 代码默认值
```

### 一、共识与性能配置

#### 1.1 出块速度优化

**配置文件**: `$CHAINDIR/config/config.toml`

```toml
[consensus]
# 标准配置 (5秒出块)
timeout_propose = "3s"
timeout_propose_delta = "500ms"
timeout_prevote = "1s"
timeout_prevote_delta = "500ms"
timeout_precommit = "1s"
timeout_precommit_delta = "500ms"
timeout_commit = "5s"  # 实际出块间隔

# 快速配置 (1秒出块) - 适用于测试环境
timeout_propose = "200ms"
timeout_propose_delta = "100ms"
timeout_prevote = "200ms"
timeout_prevote_delta = "100ms"
timeout_precommit = "200ms"
timeout_precommit_delta = "100ms"
timeout_commit = "1s"

# 超快速配置 (500ms出块) - 仅限本地测试
timeout_propose = "100ms"
timeout_propose_delta = "50ms"
timeout_prevote = "100ms"
timeout_prevote_delta = "50ms"
timeout_precommit = "100ms"
timeout_precommit_delta = "50ms"
timeout_commit = "500ms"
```

**性能影响分析**：
- 出块时间 ↓ = 吞吐量 ↑，但网络要求 ↑
- 建议：生产环境 3-5秒，测试环境 1-2秒

#### 1.2 内存池配置

```toml
[mempool]
size = 5000                    # 内存池交易数量上限
cache_size = 10000            # 缓存交易数量
max_txs_bytes = 1073741824   # 1GB - 内存池总大小
max_tx_bytes = 1048576        # 1MB - 单笔交易最大大小

# EVM 特定配置
[evm-mempool]
max_txs = 5000
prioritization = "eip1559"    # 使用 EIP-1559 优先级
```

### 二、经济模型配置

#### 2.1 初始代币供应量配置

**配置文件**: `genesis.json`

初始代币数量在创世文件中通过账户余额和银行模块来配置：

```json
{
  "app_state": {
    "bank": {
      "params": {
        "send_enabled": [],
        "default_send_enabled": true
      },
      "balances": [
        {
          "address": "cosmos1founder_address_here",
          "coins": [
            {
              "denom": "amcc",
              "amount": "1000000000000000000000000000"  // 10亿 MCC (创始人分配)
            }
          ]
        },
        {
          "address": "cosmos1validator1_address_here", 
          "coins": [
            {
              "denom": "amcc",
              "amount": "100000000000000000000000000"   // 1亿 MCC (验证人分配)
            }
          ]
        },
        {
          "address": "cosmos1treasury_address_here",
          "coins": [
            {
              "denom": "amcc", 
              "amount": "500000000000000000000000000"   // 5亿 MCC (国库分配)
            }
          ]
        }
      ],
      "supply": [
        {
          "denom": "amcc",
          "amount": "1600000000000000000000000000"      // 总供应量: 16亿 MCC
        }
      ],
      "denom_metadata": [
        {
          "description": "The native staking token for MailChat Chain.",
          "denom_units": [
            {
              "denom": "amcc",
              "exponent": 0,
              "aliases": ["attomcc"]
            },
            {
              "denom": "mcc", 
              "exponent": 18,
              "aliases": []
            }
          ],
          "base": "amcc",
          "display": "mcc",
          "name": "Mail Chat Coin",
          "symbol": "MCC",
          "uri": "",
          "uri_hash": ""
        }
      ]
    }
  }
}
```

**代币分配策略说明**：

| 分配类别 | 数量 (MCC) | 比例 | 用途 |
|---------|-----------|------|------|
| 创始人团队 | 10亿 | 62.5% | 团队激励、项目发展 |
| 验证人奖励 | 1亿 | 6.25% | 早期验证人激励 |
| 生态国库 | 5亿 | 31.25% | 社区治理、生态建设 |
| **总供应量** | **16亿** | **100%** | **初始发行总量** |

**初始代币配置脚本**：

```bash
#!/bin/bash
# setup_initial_supply.sh

# 代币配置参数
TOTAL_SUPPLY="1600000000000000000000000000"    # 16亿 MCC
FOUNDER_SUPPLY="1000000000000000000000000000"  # 10亿 MCC  
VALIDATOR_SUPPLY="100000000000000000000000000" # 1亿 MCC
TREASURY_SUPPLY="500000000000000000000000000"  # 5亿 MCC

# 地址配置（需要替换为实际地址）
FOUNDER_ADDR="cosmos1founder_address_here"
VALIDATOR_ADDR="cosmos1validator_address_here" 
TREASURY_ADDR="cosmos1treasury_address_here"

# 更新创世文件中的余额
update_genesis_balances() {
    echo "更新创世账户余额..."
    
    # 添加创始人余额
    jq --arg addr "$FOUNDER_ADDR" --arg amount "$FOUNDER_SUPPLY" '
        .app_state.bank.balances += [{
            "address": $addr,
            "coins": [{"denom": "amcc", "amount": $amount}]
        }]
    ' genesis.json > tmp_genesis.json
    
    # 添加验证人余额
    jq --arg addr "$VALIDATOR_ADDR" --arg amount "$VALIDATOR_SUPPLY" '
        .app_state.bank.balances += [{
            "address": $addr, 
            "coins": [{"denom": "amcc", "amount": $amount}]
        }]
    ' tmp_genesis.json > tmp_genesis2.json
    
    # 添加国库余额
    jq --arg addr "$TREASURY_ADDR" --arg amount "$TREASURY_SUPPLY" '
        .app_state.bank.balances += [{
            "address": $addr,
            "coins": [{"denom": "amcc", "amount": $amount}]
        }]
    ' tmp_genesis2.json > tmp_genesis3.json
    
    # 设置总供应量
    jq --arg total "$TOTAL_SUPPLY" '
        .app_state.bank.supply = [{
            "denom": "amcc",
            "amount": $total
        }]
    ' tmp_genesis3.json > genesis_new.json
    
    # 清理临时文件
    rm tmp_genesis.json tmp_genesis2.json tmp_genesis3.json
    mv genesis_new.json genesis.json
    
    echo "初始代币分配配置完成!"
}

# 验证配置
validate_supply() {
    echo "验证代币供应量配置..."
    
    # 检查总供应量
    CONFIGURED_SUPPLY=$(jq -r '.app_state.bank.supply[0].amount' genesis.json)
    echo "配置的总供应量: $CONFIGURED_SUPPLY"
    
    # 计算账户余额总和
    TOTAL_BALANCES=$(jq -r '
        .app_state.bank.balances 
        | map(select(.coins[0].denom == "amcc") | .coins[0].amount | tonumber) 
        | add
    ' genesis.json)
    echo "账户余额总和: $TOTAL_BALANCES"
    
    # 验证是否匹配
    if [ "$CONFIGURED_SUPPLY" = "$TOTAL_BALANCES" ]; then
        echo "✅ 供应量配置正确"
    else
        echo "❌ 供应量不匹配，请检查配置"
        exit 1
    fi
}

# 执行配置
update_genesis_balances
validate_supply

echo "初始代币供应量配置完成！"
```

**动态供应量管理**：

```bash
# 查询当前总供应量
mailchatd query bank total --home $HOME/.mailchatd

# 查询特定代币供应量
mailchatd query bank total amcc --home $HOME/.mailchatd

# 查询账户余额
mailchatd query bank balances cosmos1address... --home $HOME/.mailchatd

# 查询所有余额（用于验证）
mailchatd query bank balances-all --home $HOME/.mailchatd
```

#### 2.2 通胀参数

**配置文件**: `genesis.json`

```json
{
  "app_state": {
    "mint": {
      "minter": {
        "inflation": "0.130000000000000000",
        "annual_provisions": "0.000000000000000000"
      },
      "params": {
        "mint_denom": "amcc",
        "inflation_rate_change": "0.130000000000000000",
        "inflation_max": "0.200000000000000000",  // 20%
        "inflation_min": "0.070000000000000000",  // 7%
        "goal_bonded": "0.670000000000000000",    // 67%
        "blocks_per_year": "6311520"              // 基于5秒出块
      }
    }
  }
}
```

**通胀率调整脚本**：

```bash
#!/bin/bash
# adjust_inflation.sh

# 设置新的通胀参数
NEW_MAX="0.150000000000000000"  # 15%
NEW_MIN="0.050000000000000000"  # 5%
NEW_GOAL="0.500000000000000000" # 50%

# 更新 genesis.json
jq --arg max "$NEW_MAX" --arg min "$NEW_MIN" --arg goal "$NEW_GOAL" '
  .app_state.mint.params.inflation_max = $max |
  .app_state.mint.params.inflation_min = $min |
  .app_state.mint.params.goal_bonded = $goal
' genesis.json > genesis_new.json

mv genesis_new.json genesis.json
echo "通胀参数已更新"
```

#### 2.2 质押参数

```json
{
  "app_state": {
    "staking": {
      "params": {
        "unbonding_time": "1814400s",        // 21天
        "max_validators": 100,                // 最大验证人数
        "max_entries": 7,                     // 解绑队列大小
        "historical_entries": 10000,
        "bond_denom": "amcc",
        "min_commission_rate": "0.050000000000000000"  // 5%最低佣金
      }
    }
  }
}
```

**快速测试配置**：

```bash
# 1小时解绑期（仅测试）
jq '.app_state.staking.params.unbonding_time = "3600s"' genesis.json > tmp.json
mv tmp.json genesis.json
```

#### 2.3 分配参数

```json
{
  "app_state": {
    "distribution": {
      "params": {
        "community_tax": "0.020000000000000000",        // 2% 社区税
        "base_proposer_reward": "0.010000000000000000", // 1% 基础奖励
        "bonus_proposer_reward": "0.040000000000000000" // 4% 额外奖励
      }
    }
  }
}
```

### 三、EVM 配置

#### 3.1 Gas 和费用设置

**配置文件**: `app.toml`

```toml
[evm]
# EVM 链 ID
evm-chain-id = 26000

# Gas 设置
max-tx-gas-wanted = 0          # 0 = 无限制
max-tx-gas-per-block = 10000000

# 追踪器配置
tracer = ""                    # "json" 用于详细追踪
debug-trace-enable = false

[json-rpc]
# RPC 配置
enable = true
address = "0.0.0.0:8545"
ws-address = "0.0.0.0:8546"

# API 命名空间
api = "eth,net,web3,debug,personal,miner,txpool"

# Gas 限制
gas-cap = 25000000            # 单次调用 gas 上限
txfee-cap = 1                 # 1 ETH 等值费用上限

# 过滤器设置
filter-cap = 200              # 最大过滤器数量
fee-history-cap = 100         # 费用历史记录数

# 日志设置
log-cap = 10000              # 日志返回上限
block-range-cap = 10000      # 区块范围查询上限

# 超时设置
evm-timeout = "5s"           # EVM 执行超时
http-timeout = "30s"         # HTTP 请求超时
```

#### 3.2 费用市场（EIP-1559）

```json
{
  "app_state": {
    "feemarket": {
      "params": {
        "no_base_fee": false,
        "base_fee_change_denominator": 8,
        "elasticity_multiplier": 2,
        "enable_height": "0",
        "base_fee": "1000000000",              // 1 Gwei
        "min_gas_price": "0.000000000000000000",
        "min_gas_multiplier": "0.500000000000000000"
      }
    }
  }
}
```

**动态调整基础费用**：

```javascript
// Web3.js 示例
const Web3 = require('web3');
const web3 = new Web3('http://localhost:8545');

async function getGasPrice() {
    // 获取当前基础费用
    const block = await web3.eth.getBlock('latest');
    const baseFee = block.baseFeePerGas;
    
    // 计算推荐 gas 价格
    const maxPriorityFee = web3.utils.toWei('2', 'gwei');
    const maxFee = BigInt(baseFee) + BigInt(maxPriorityFee);
    
    return {
        baseFee: baseFee,
        maxPriorityFeePerGas: maxPriorityFee,
        maxFeePerGas: maxFee.toString()
    };
}
```

### 四、网络配置

#### 4.1 P2P 网络

```toml
[p2p]
# 监听地址
laddr = "tcp://0.0.0.0:26656"

# 种子节点
seeds = "node_id@ip:26656,node_id2@ip2:26656"

# 持久节点
persistent_peers = "node_id@ip:26656"

# 最大连接数
max_num_inbound_peers = 40
max_num_outbound_peers = 10

# 连接超时
handshake_timeout = "20s"
dial_timeout = "3s"

# 种子模式
seed_mode = false

# 私有节点 ID（不会广播）
private_peer_ids = ""

# 允许重复 IP
allow_duplicate_ip = false
```

#### 4.2 RPC 配置

```toml
[rpc]
# RPC 监听地址
laddr = "tcp://127.0.0.1:26657"

# CORS 设置
cors_allowed_origins = ["*"]
cors_allowed_methods = ["HEAD", "GET", "POST"]
cors_allowed_headers = ["Origin", "Accept", "Content-Type"]

# gRPC
grpc_laddr = ""
grpc_max_open_connections = 900

# WebSocket
max_open_connections = 900
max_subscription_clients = 100
max_subscriptions_per_client = 5
timeout_broadcast_tx_commit = "10s"

# 限流
max_body_bytes = 1000000  # 1MB
max_header_bytes = 1048576
```

---

## 邮件服务器配置

### DNS配置和TLS证书

邮件服务器使用ACME自动获取TLS证书，支持多种DNS提供商进行DNS-01验证。

#### 支持的DNS提供商

系统支持15种DNS提供商：

| 编号 | 提供商 | 所需凭据 |
|------|---------|----------|
| 1 | Cloudflare | API Token |
| 2 | Amazon Route53 | Access Key ID, Secret Access Key |
| 3 | DigitalOcean | API Token |
| 4 | GoDaddy | API Key, API Secret |
| 5 | Google Cloud DNS | Service Account JSON |
| 6 | Namecheap | API User, API Token, User IP |
| 7 | Vultr | API Key |
| 8 | Linode | API Token |
| 9 | Azure DNS | Subscription ID, Resource Group, Tenant ID, Client ID, Client Secret |
| 10 | OVH | Application Key, Application Secret, Consumer Key |
| 11 | Hetzner | API Token |
| 12 | Gandi | API Token |
| 13 | Porkbun | API Key, Secret API Key |
| 14 | DuckDNS | Token |
| 15 | Hurricane Electric | Username, Password |

#### DNS配置示例

在配置文件中使用简化的提供商名称：

```
tls {
    loader acme {
        hostname $(hostname)
        email postmaster@$(hostname)
        agreed
        challenge dns-01
        dns cloudflare {
            api_token YOUR_API_TOKEN
        }
    }
}
```

### 自动化安装脚本

项目提供`start.sh`脚本用于自动化部署：

#### 功能特性

1. **自动安装**：下载并安装mailchatd二进制文件
2. **配置管理**：自动生成配置文件并设置DNS提供商
3. **服务管理**：创建并启动systemd服务
4. **公网IP检测**：自动获取服务器公网IP地址
5. **多DNS支持**：支持15种DNS提供商的凭据配置

#### 使用方法

```bash
# 运行安装脚本
./start.sh

# 脚本将引导您完成：
# 1. 选择工作目录（默认：$NODE_HOME 或 /root/.mailchatd）
# 2. 输入域名配置
# 3. 选择DNS提供商
# 4. 配置DNS凭据
# 5. 自动启动服务
```

#### 配置文件模板

系统使用`mailchatd.conf`作为配置模板，包含：

- **基础变量**：域名、本地域名设置
- **TLS配置**：ACME自动证书获取
- **区块链配置**：以太坊兼容链连接
- **存储配置**：SQLite数据库存储
- **认证配置**：区块链钱包认证
- **SMTP/IMAP服务**：邮件收发服务

### 区块链集成

#### 认证机制

使用EVM兼容区块链进行用户认证：

```
auth.pass_evm blockchain_auth {
    blockchain &mailchatd
    storage &local_mailboxes
}
```

#### 交易记录

邮件操作会记录到区块链：

```
modify {
    blockchain_tx &mailchatd
}
```

### 服务管理

#### Systemd服务

系统创建两个服务：

1. **mailchatd.service**：主邮件服务
2. **mailchatd-mail.service**：邮件处理服务

#### 环境配置

服务使用`/etc/mailchatd/environment`环境文件：

```
NODE_HOME=/your/work/directory
```

### 故障排除

#### 区块链同步问题

如遇到区块链同步错误：

```bash
# 重置区块链数据
mailchatd comet unsafe-reset-all

# 重新下载genesis文件
curl -o ~/.mailchatd/config/genesis.json https://raw.githubusercontent.com/your-repo/genesis.json
```

#### DNS配置验证

使用DNS子命令验证配置：

```bash
# 检查DNS配置
mailchatd dns check

# 导出DNS记录
mailchatd dns export

# 配置向导
mailchatd dns config
```

---

## 节点运维

### 一、验证人节点部署

#### 1.1 硬件要求

```yaml
最低配置:
  CPU: 4核
  内存: 8GB
  存储: 200GB SSD
  带宽: 100Mbps

推荐配置:
  CPU: 8核
  内存: 32GB
  存储: 1TB NVMe SSD
  带宽: 1Gbps
```

#### 1.2 创建验证人

```bash
# 1. 获取节点公钥
NODE_PUBKEY=$(mailchatd tendermint show-validator --home $CHAINDIR)

# 2. 创建验证人
mailchatd tx staking create-validator \
  --amount=100000000000000000000000amcc \
  --pubkey=$NODE_PUBKEY \
  --moniker="MyValidator" \
  --identity="Keybase ID" \
  --details="Professional validator service" \
  --website="https://validator.example.com" \
  --security-contact="security@example.com" \
  --chain-id=$CHAINID \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="10000000000000000000000" \
  --gas="300000" \
  --gas-prices="0.025amcc" \
  --from=validator \
  --home=$CHAINDIR
```

#### 1.3 监控脚本

```bash
#!/bin/bash
# monitor.sh - 验证人监控脚本

VALIDATOR_ADDR="cosmosvaloper1..."
RPC="http://localhost:26657"

while true; do
    # 检查节点状态
    STATUS=$(curl -s $RPC/status | jq -r '.result.sync_info.catching_up')
    
    # 检查签名状态
    MISSED=$(mailchatd query slashing signing-info $VALIDATOR_ADDR \
             --home $CHAINDIR | grep missed_blocks_counter)
    
    # 检查验证人状态
    JAILED=$(mailchatd query staking validator $VALIDATOR_ADDR \
             --home $CHAINDIR | grep jailed)
    
    echo "$(date): Syncing=$STATUS, Missed=$MISSED, Jailed=$JAILED"
    
    # 告警逻辑
    if [[ "$JAILED" == *"true"* ]]; then
        echo "警告: 验证人被监禁!"
        # 发送告警通知
    fi
    
    sleep 60
done
```

### 二、节点备份与恢复

#### 2.1 数据备份

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/mailchatd"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 停止节点
systemctl stop mailchatd

# 备份数据
tar -czf $BACKUP_DIR/backup_$TIMESTAMP.tar.gz \
    $CHAINDIR/data \
    $CHAINDIR/config/priv_validator_key.json \
    $CHAINDIR/config/node_key.json

# 重启节点
systemctl start mailchatd

echo "备份完成: backup_$TIMESTAMP.tar.gz"
```

#### 2.2 状态同步

```toml
# config.toml - 启用状态同步
[statesync]
enable = true
rpc_servers = "node1:26657,node2:26657"
trust_height = 1000
trust_hash = "hash_at_height_1000"
trust_period = "168h0m0s"
discovery_time = "15s"
```

### 三、性能优化

#### 3.1 数据库优化

```toml
# app.toml
[pruning]
# 修剪策略
pruning = "custom"
pruning-keep-recent = "100"    # 保留最近100个区块
pruning-interval = "10"         # 每10个区块修剪一次

[state-sync]
# 快照设置
snapshot-interval = 1000        # 每1000块创建快照
snapshot-keep-recent = 2        # 保留2个快照
```

#### 3.2 内存优化

```bash
# 设置系统参数
sudo sysctl -w vm.swappiness=10
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
```

---

## 质押与治理

### 一、质押操作

#### 1.1 委托质押

```bash
# 查看验证人列表
mailchatd query staking validators --home $CHAINDIR

# 委托到验证人
mailchatd tx staking delegate \
  cosmosvaloper1abcdef... \
  10000000000000000000000amcc \
  --from=user1 \
  --chain-id=$CHAINID \
  --gas=200000 \
  --gas-prices=0.025amcc \
  --home=$CHAINDIR
```

#### 1.2 收益管理

```bash
# 查询收益
mailchatd query distribution rewards \
  cosmos1user... \
  cosmosvaloper1validator... \
  --home $CHAINDIR

# 领取所有收益
mailchatd tx distribution withdraw-all-rewards \
  --from=user1 \
  --chain-id=$CHAINID \
  --gas=auto \
  --gas-adjustment=1.5 \
  --home=$CHAINDIR

# 自动复投脚本
#!/bin/bash
while true; do
    # 领取收益
    mailchatd tx distribution withdraw-all-rewards \
        --from=user1 --chain-id=$CHAINID -y
    
    # 查询余额
    BALANCE=$(mailchatd query bank balances cosmos1... \
              --denom=amcc -o json | jq -r '.amount')
    
    # 保留 1000 MCC 作为手续费
    RESERVE=1000000000000000000000
    DELEGATE=$((BALANCE - RESERVE))
    
    if [ $DELEGATE -gt 0 ]; then
        # 复投
        mailchatd tx staking delegate \
            cosmosvaloper1... \
            ${DELEGATE}amcc \
            --from=user1 --chain-id=$CHAINID -y
    fi
    
    sleep 86400  # 每天执行一次
done
```

### 二、链上治理

#### 2.1 提案类型

| 类型 | 描述 | 示例 |
|------|------|------|
| **文本提案** | 非约束性提案 | 社区倡议、路线图 |
| **参数变更** | 修改链参数 | 调整通胀率、Gas限制 |
| **软件升级** | 协调链升级 | 版本更新、硬分叉 |
| **社区支出** | 使用社区资金 | 资助开发、营销 |

#### 2.2 创建提案

```bash
# 创建参数变更提案
cat > proposal.json << EOF
{
  "title": "Increase Block Gas Limit",
  "description": "Proposal to increase block gas limit from 10M to 20M",
  "changes": [
    {
      "subspace": "evm",
      "key": "MaxTxGasWanted",
      "value": "20000000"
    }
  ],
  "deposit": "10000000000000000000000amcc"
}
EOF

# 提交提案
mailchatd tx gov submit-proposal param-change proposal.json \
  --from=validator \
  --chain-id=$CHAINID \
  --home=$CHAINDIR
```

#### 2.3 投票流程

```bash
# 查看提案
mailchatd query gov proposals --home $CHAINDIR

# 投票
mailchatd tx gov vote 1 yes \
  --from=user1 \
  --chain-id=$CHAINID \
  --home=$CHAINDIR

# 投票选项：yes | no | abstain | no_with_veto
```

### 三、智能合约集成

#### 3.1 质押预编译合约

```solidity
// IStaking.sol
pragma solidity ^0.8.0;

interface IStaking {
    function delegate(
        address delegator,
        string memory validator,
        uint256 amount
    ) external returns (bool);
    
    function undelegate(
        address delegator,
        string memory validator,
        uint256 amount
    ) external returns (uint256);
    
    function redelegate(
        address delegator,
        string memory srcValidator,
        string memory dstValidator,
        uint256 amount
    ) external returns (uint256);
}

// StakingPool.sol
contract StakingPool {
    IStaking constant STAKING = IStaking(0x0000000000000000000000000000000000000800);
    
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    string public validator;
    
    constructor(string memory _validator) {
        validator = _validator;
    }
    
    function deposit() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        
        // 计算份额
        uint256 newShares = msg.value;
        if (totalShares > 0) {
            newShares = (msg.value * totalShares) / address(this).balance;
        }
        
        // 更新份额
        shares[msg.sender] += newShares;
        totalShares += newShares;
        
        // 委托到验证人
        STAKING.delegate(address(this), validator, msg.value);
    }
    
    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");
        
        // 计算提取金额
        uint256 amount = (shareAmount * address(this).balance) / totalShares;
        
        // 更新份额
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        
        // 解除委托并转账
        STAKING.undelegate(address(this), validator, amount);
        payable(msg.sender).transfer(amount);
    }
}
```

---

## 跨链桥（IBC）

### 一、IBC 基础设置

#### 1.1 安装 Hermes 中继器

```bash
# 下载并安装
curl -L https://github.com/informalsystems/hermes/releases/download/v1.7.4/hermes-v1.7.4-x86_64-unknown-linux-gnu.tar.gz | tar xz
sudo mv hermes /usr/local/bin/

# 验证安装
hermes version
```

#### 1.2 配置中继器

```toml
# ~/.hermes/config.toml
[global]
log_level = 'info'
[mode.clients]
enabled = true
refresh = true
misbehaviour = true
[mode.connections]
enabled = true
[mode.channels]
enabled = true
[mode.packets]
enabled = true
clear_interval = 100
clear_on_start = true
tx_confirmation = false

[[chains]]
id = 'cosmos_262144-1'
type = 'CosmosSdk'
rpc_addr = 'http://127.0.0.1:26657'
grpc_addr = 'http://127.0.0.1:9090'
websocket_addr = 'ws://127.0.0.1:26657/websocket'
rpc_timeout = '10s'
account_prefix = 'cosmos'
key_name = 'relayer'
store_prefix = 'ibc'
gas_price = { price = 0.001, denom = 'amcc' }
gas_multiplier = 1.2
max_gas = 10000000
max_msg_num = 30
max_tx_size = 2097152
trusting_period = '14days'
trust_threshold = { numerator = '1', denominator = '3' }

[[chains]]
id = 'osmosis-1'
type = 'CosmosSdk'
rpc_addr = 'https://rpc.osmosis.zone:443'
grpc_addr = 'https://grpc.osmosis.zone:443'
websocket_addr = 'wss://rpc.osmosis.zone:443/websocket'
rpc_timeout = '10s'
account_prefix = 'osmo'
key_name = 'osmosis'
store_prefix = 'ibc'
gas_price = { price = 0.0025, denom = 'uosmo' }
gas_multiplier = 1.2
max_gas = 10000000
```

### 二、建立 IBC 连接

#### 2.1 创建连接步骤

```bash
# 1. 添加密钥
hermes keys add --chain cosmos_262144-1 --key-file key1.json
hermes keys add --chain osmosis-1 --key-file key2.json

# 2. 创建客户端、连接和通道
hermes create channel \
  --a-chain cosmos_262144-1 \
  --b-chain osmosis-1 \
  --a-port transfer \
  --b-port transfer \
  --new-client-connection --yes

# 3. 启动中继器
hermes start
```

#### 2.2 IBC 传输示例

```bash
# CLI 传输
mailchatd tx ibc-transfer transfer \
  transfer \
  channel-0 \
  osmo1recipient... \
  1000000amcc \
  --from=user1 \
  --chain-id=$CHAINID \
  --packet-timeout-height="0-1000" \
  --packet-timeout-timestamp="0" \
  --home=$CHAINDIR

# 查询 IBC 余额
mailchatd query bank balances cosmos1... \
  --denom="ibc/27394FB..." \
  --home=$CHAINDIR
```

### 三、IBC 智能合约集成

```solidity
// ICS20Transfer.sol
pragma solidity ^0.8.0;

interface IICS20 {
    function transfer(
        string memory sourcePort,
        string memory sourceChannel,
        string memory denom,
        uint256 amount,
        address sender,
        string memory receiver,
        RevisionHeight memory revisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external returns (bool);
    
    struct RevisionHeight {
        uint64 revisionNumber;
        uint64 revisionHeight;
    }
}

contract CrossChainBridge {
    IICS20 constant ICS20 = IICS20(0x0000000000000000000000000000000000000802);
    
    event IBCTransferInitiated(
        address indexed sender,
        string recipient,
        uint256 amount,
        string channel
    );
    
    function bridgeTokens(
        string memory channel,
        string memory cosmosRecipient,
        uint256 amount
    ) external {
        // 转移代币到合约
        require(msg.value == amount, "Incorrect amount");
        
        // 设置超时（10分钟后）
        uint64 timeoutTimestamp = uint64(block.timestamp + 600) * 1e9;
        
        // 执行 IBC 传输
        bool success = ICS20.transfer(
            "transfer",
            channel,
            "amcc",
            amount,
            msg.sender,
            cosmosRecipient,
            IICS20.RevisionHeight(0, 0),
            timeoutTimestamp,
            ""
        );
        
        require(success, "IBC transfer failed");
        
        emit IBCTransferInitiated(
            msg.sender,
            cosmosRecipient,
            amount,
            channel
        );
    }
}
```

---

## 开发指南

### 一、环境设置

#### 1.1 开发工具链

```bash
# 安装开发依赖
npm install -g truffle hardhat
pip install web3 eth-account

# 配置 Hardhat
cat > hardhat.config.js << EOF
module.exports = {
  networks: {
    mailchat: {
      url: "http://localhost:8545",
      chainId: 26000,
      accounts: ["YOUR_PRIVATE_KEY"]
    }
  },
  solidity: "0.8.20"
};
EOF
```

#### 1.2 SDK 集成

**JavaScript/TypeScript**:

```typescript
import { ethers } from 'ethers';
import { SigningStargateClient } from '@cosmjs/stargate';

// EVM 连接
const evmProvider = new ethers.JsonRpcProvider('http://localhost:8545');
const evmWallet = new ethers.Wallet('PRIVATE_KEY', evmProvider);

// Cosmos 连接
const cosmosRpc = 'http://localhost:26657';
const cosmosWallet = await SigningStargateClient.connectWithSigner(
    cosmosRpc,
    wallet
);

// 双重交易示例
async function dualTransaction() {
    // EVM 交易
    const evmTx = await evmWallet.sendTransaction({
        to: '0x...',
        value: ethers.parseEther('1.0')
    });
    
    // Cosmos 交易
    const cosmosTx = await cosmosWallet.sendTokens(
        senderAddress,
        recipientAddress,
        [{ denom: 'amcc', amount: '1000000' }],
        'auto'
    );
    
    return { evmTx, cosmosTx };
}
```

**Python**:

```python
from web3 import Web3
from cosmpy.aerial.client import LedgerClient
from cosmpy.aerial.wallet import LocalWallet

# EVM 连接
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))
account = w3.eth.account.from_key('PRIVATE_KEY')

# Cosmos 连接
ledger = LedgerClient('http://localhost:26657')
wallet = LocalWallet.from_mnemonic('MNEMONIC')

# 查询余额
evm_balance = w3.eth.get_balance(account.address)
cosmos_balance = ledger.query_bank_balance(wallet.address(), 'amcc')
```

### 二、智能合约开发

#### 2.1 预编译合约集成示例

**完整的 DeFi 质押池合约**

```solidity
// StakingPool.sol - 使用预编译合约的质押池
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// 预编译合约接口
interface IStaking {
    function delegate(address delegator, string memory validator, uint256 amount) external returns (bool);
    function undelegate(address delegator, string memory validator, uint256 amount) external returns (uint256);
    function redelegate(address delegator, string memory srcValidator, string memory dstValidator, uint256 amount) external returns (uint256);
}

interface IDistribution {
    function withdrawDelegatorReward(address delegator, string memory validator) external returns (uint256);
    function withdrawAllRewards(address delegator) external returns (uint256);
}

interface IGovernance {
    function vote(uint64 proposalId, uint8 option) external returns (bool);
    function submitProposal(string memory title, string memory description, uint256 initialDeposit) external returns (uint64);
}

contract MailChatStakingPool is ERC20, ReentrancyGuard {
    // 预编译合约常量地址
    IStaking constant STAKING = IStaking(0x0000000000000000000000000000000000000800);
    IDistribution constant DISTRIBUTION = IDistribution(0x0000000000000000000000000000000000000801);
    IGovernance constant GOVERNANCE = IGovernance(0x0000000000000000000000000000000000000803);
    
    string public validator;
    address public manager;
    uint256 public totalStaked;
    
    mapping(address => uint256) public userShares;
    mapping(uint64 => mapping(address => uint8)) public userVotes; // proposalId => user => vote
    
    event Staked(address indexed user, uint256 amount, uint256 shares);
    event Unstaked(address indexed user, uint256 amount, uint256 shares);
    event RewardsDistributed(uint256 totalRewards, uint256 timestamp);
    event ProposalVoted(uint64 indexed proposalId, uint8 option, uint256 votingPower);

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call this");
        _;
    }

    constructor(string memory _validator, address _manager) 
        ERC20("MailChat Staking Shares", "mcSTAKE") {
        validator = _validator;
        manager = _manager;
    }

    /**
     * @dev 用户质押 MCC 代币，获得质押份额
     */
    function stake() external payable nonReentrant {
        require(msg.value > 0, "Cannot stake 0");
        
        uint256 shares;
        if (totalSupply() == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * totalSupply()) / totalStaked;
        }
        
        // 通过预编译合约委托质押
        require(
            STAKING.delegate(address(this), validator, msg.value),
            "Delegation failed"
        );
        
        totalStaked += msg.value;
        userShares[msg.sender] += shares;
        _mint(msg.sender, shares);
        
        emit Staked(msg.sender, msg.value, shares);
    }

    /**
     * @dev 用户解除质押，销毁份额获得 MCC
     */
    function unstake(uint256 shares) external nonReentrant {
        require(shares > 0, "Cannot unstake 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        
        uint256 amountToUnstake = (shares * totalStaked) / totalSupply();
        
        // 通过预编译合约解除委托
        uint256 unbondingTime = STAKING.undelegate(address(this), validator, amountToUnstake);
        
        totalStaked -= amountToUnstake;
        userShares[msg.sender] -= shares;
        _burn(msg.sender, shares);
        
        // 注意：实际的MCC将在unbondingTime之后可以提取
        // 这里简化处理，实际应该实现unbonding队列管理
        
        emit Unstaked(msg.sender, amountToUnstake, shares);
    }

    /**
     * @dev 领取质押奖励并重新投入
     */
    function compoundRewards() external onlyManager {
        uint256 rewards = DISTRIBUTION.withdrawDelegatorReward(address(this), validator);
        
        if (rewards > 0) {
            // 将奖励重新质押
            require(
                STAKING.delegate(address(this), validator, rewards),
                "Reward restaking failed"
            );
            
            totalStaked += rewards;
            emit RewardsDistributed(rewards, block.timestamp);
        }
    }

    /**
     * @dev 治理投票 - 使用质押池的总投票权重
     */
    function voteOnProposal(uint64 proposalId, uint8 option) external onlyManager {
        require(option <= 3, "Invalid vote option"); // 0=Abstain, 1=Yes, 2=No, 3=NoWithVeto
        
        require(
            GOVERNANCE.vote(proposalId, option),
            "Governance vote failed"
        );
        
        emit ProposalVoted(proposalId, option, totalStaked);
    }

    /**
     * @dev 创建治理提案
     */
    function createProposal(
        string memory title,
        string memory description
    ) external payable onlyManager returns (uint64) {
        require(msg.value >= 10000000000000000000000, "Insufficient deposit"); // 10000 MCC minimum
        
        uint64 proposalId = GOVERNANCE.submitProposal(title, description, msg.value);
        return proposalId;
    }

    /**
     * @dev 获取用户的质押信息
     */
    function getUserInfo(address user) external view returns (
        uint256 shares,
        uint256 stakedAmount,
        uint256 sharePercentage
    ) {
        shares = balanceOf(user);
        if (totalSupply() > 0) {
            stakedAmount = (shares * totalStaked) / totalSupply();
            sharePercentage = (shares * 10000) / totalSupply(); // 基点表示
        }
    }

    /**
     * @dev 切换验证人（重新委托）
     */
    function switchValidator(string memory newValidator) external onlyManager {
        uint256 completionTime = STAKING.redelegate(
            address(this),
            validator,
            newValidator,
            totalStaked
        );
        
        validator = newValidator;
        // 注意：重新委托有完成时间限制
    }
}
```

**跨链桥接合约示例**

```solidity
// CrossChainBridge.sol - 使用 ICS20 预编译的跨链桥
pragma solidity ^0.8.20;

interface IICS20 {
    function transfer(
        string memory sourcePort,
        string memory sourceChannel,
        string memory denom,
        uint256 amount,
        address sender,
        string memory receiver,
        RevisionHeight memory revisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external returns (bool);
    
    struct RevisionHeight {
        uint64 revisionNumber;
        uint64 revisionHeight;
    }
}

interface IBankPrecompile {
    function send(
        address from,
        address to,
        uint256 amount,
        string memory denom
    ) external returns (bool);
}

contract MailChatBridge {
    IICS20 constant ICS20 = IICS20(0x0000000000000000000000000000000000000802);
    IBankPrecompile constant BANK = IBankPrecompile(0x0000000000000000000000000000000000000805);
    
    mapping(string => bool) public supportedChannels;
    mapping(address => uint256) public pendingTransfers;
    
    event CrossChainTransferInitiated(
        address indexed sender,
        string recipient,
        uint256 amount,
        string channel,
        string memo
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    address public owner;
    
    constructor() {
        owner = msg.sender;
        // 添加支持的IBC通道
        supportedChannels["channel-0"] = true; // Osmosis
        supportedChannels["channel-1"] = true; // Cosmos Hub
    }
    
    /**
     * @dev 跨链转账到其他Cosmos链
     */
    function bridgeToChain(
        string memory channel,
        string memory cosmosRecipient,
        string memory memo
    ) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(supportedChannels[channel], "Unsupported channel");
        require(bytes(cosmosRecipient).length > 0, "Invalid recipient");
        
        // 设置10分钟超时
        uint64 timeoutTimestamp = uint64(block.timestamp + 600) * 1e9;
        
        // 执行IBC转账
        bool success = ICS20.transfer(
            "transfer",
            channel,
            "amcc",
            msg.value,
            msg.sender,
            cosmosRecipient,
            IICS20.RevisionHeight(0, 0),
            timeoutTimestamp,
            memo
        );
        
        require(success, "Cross-chain transfer failed");
        
        emit CrossChainTransferInitiated(
            msg.sender,
            cosmosRecipient,
            msg.value,
            channel,
            memo
        );
    }
    
    /**
     * @dev 批量跨链转账
     */
    function batchBridge(
        string memory channel,
        string[] memory recipients,
        uint256[] memory amounts,
        string memory memo
    ) external payable {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length <= 10, "Too many recipients");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(msg.value >= totalAmount, "Insufficient payment");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                uint64 timeoutTimestamp = uint64(block.timestamp + 600) * 1e9;
                
                ICS20.transfer(
                    "transfer",
                    channel,
                    "amcc",
                    amounts[i],
                    msg.sender,
                    recipients[i],
                    IICS20.RevisionHeight(0, 0),
                    timeoutTimestamp,
                    memo
                );
            }
        }
    }
}
```

#### 2.2 Account Abstraction 预编译使用

**无 Bundler 的 EIP-4337 实现**

```solidity
// BundlerFreeAccount.sol - 使用预编译的账户抽象
pragma solidity ^0.8.20;

interface IAccountAbstraction {
    function validateUserOp(bytes memory userOpData) external returns (bytes32);
    function getUserOpHash(bytes memory userOpData) external view returns (bytes32);
    function createAccount(address owner, bytes memory initData) external returns (address);
    function getNonce(address account) external view returns (uint256);
    function validatePaymaster(bytes memory paymasterData) external returns (bytes memory, bytes memory);
    function calculatePrefund(bytes memory userOpData) external view returns (uint256);
    function simulateValidation(bytes memory userOpData) external view returns (bytes memory, bytes memory, bytes memory);
}

contract BundlerFreeEntryPoint {
    IAccountAbstraction constant AA = IAccountAbstraction(0x0000000000000000000000000000000000000808);
    
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
    
    // 用户操作队列 - 替代传统的 bundler 内存池
    mapping(bytes32 => UserOperation) public queuedOps;
    bytes32[] public executionQueue;
    mapping(address => uint256) public executorRewards;
    
    event UserOperationQueued(bytes32 indexed hash, address indexed sender);
    event UserOperationExecuted(bytes32 indexed hash, address indexed executor, uint256 reward);
    
    /**
     * @dev 用户直接提交操作到链上队列
     */
    function submitUserOperation(
        UserOperation memory userOp,
        uint256 executorTip
    ) external payable returns (bytes32) {
        require(msg.value >= executorTip + userOp.maxFeePerGas * userOp.verificationGasLimit, "Insufficient payment");
        
        // 使用预编译验证和获取哈希
        bytes memory userOpData = abi.encode(userOp);
        bytes32 hash = AA.getUserOpHash(userOpData);
        
        // 预验证操作
        AA.validateUserOp(userOpData);
        
        // 添加到执行队列
        queuedOps[hash] = userOp;
        executionQueue.push(hash);
        
        emit UserOperationQueued(hash, userOp.sender);
        return hash;
    }
    
    /**
     * @dev 任何人都可以执行队列中的操作并获得奖励
     */
    function executeUserOperations(uint256 maxOps) external {
        require(maxOps > 0 && maxOps <= 5, "Invalid batch size");
        
        uint256 opsToExecute = maxOps > executionQueue.length ? executionQueue.length : maxOps;
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < opsToExecute; i++) {
            bytes32 hash = executionQueue[i];
            UserOperation memory userOp = queuedOps[hash];
            
            // 使用预编译模拟验证
            bytes memory userOpData = abi.encode(userOp);
            (bytes memory accountValidation, bytes memory paymasterValidation, bytes memory aggregatorValidation) = AA.simulateValidation(userOpData);
            
            // 执行用户操作
            if (_executeUserOp(userOp)) {
                // 给执行者奖励
                uint256 reward = userOp.maxPriorityFeePerGas * userOp.callGasLimit / 100; // 1% 作为奖励
                totalReward += reward;
                
                emit UserOperationExecuted(hash, msg.sender, reward);
            }
            
            // 从队列中移除
            delete queuedOps[hash];
        }
        
        // 清理执行队列
        for (uint256 i = opsToExecute; i < executionQueue.length; i++) {
            executionQueue[i - opsToExecute] = executionQueue[i];
        }
        for (uint256 i = 0; i < opsToExecute; i++) {
            executionQueue.pop();
        }
        
        // 支付奖励
        if (totalReward > 0) {
            executorRewards[msg.sender] += totalReward;
            payable(msg.sender).transfer(totalReward);
        }
    }
    
    function _executeUserOp(UserOperation memory userOp) internal returns (bool) {
        // 实际执行用户操作的逻辑
        // 这里简化处理，实际应该调用目标合约
        (bool success, ) = userOp.sender.call{gas: userOp.callGasLimit}(userOp.callData);
        return success;
    }
    
    /**
     * @dev 创建新的智能账户
     */
    function createSmartAccount(
        address owner,
        bytes memory initData
    ) external returns (address) {
        return AA.createAccount(owner, initData);
    }
    
    /**
     * @dev 获取账户的下一个nonce
     */
    function getAccountNonce(address account) external view returns (uint256) {
        return AA.getNonce(account);
    }
}
```

#### 2.3 部署和测试脚本

```javascript
// deploy-precompile-examples.js
const hre = require("hardhat");

async function main() {
    console.log("Deploying MailChat Chain precompile integration contracts...");
    
    // 1. 部署质押池合约
    console.log("\n1. Deploying Staking Pool...");
    const StakingPool = await hre.ethers.getContractFactory("MailChatStakingPool");
    const stakingPool = await StakingPool.deploy(
        "cosmosvaloper1abcdef...", // 验证人地址
        "0x1234567890123456789012345678901234567890" // 管理员地址
    );
    await stakingPool.waitForDeployment();
    console.log("✅ StakingPool deployed to:", await stakingPool.getAddress());
    
    // 2. 部署跨链桥合约
    console.log("\n2. Deploying Cross-Chain Bridge...");
    const Bridge = await hre.ethers.getContractFactory("MailChatBridge");
    const bridge = await Bridge.deploy();
    await bridge.waitForDeployment();
    console.log("✅ CrossChainBridge deployed to:", await bridge.getAddress());
    
    // 3. 部署 Account Abstraction 入口点
    console.log("\n3. Deploying Bundler-Free EntryPoint...");
    const EntryPoint = await hre.ethers.getContractFactory("BundlerFreeEntryPoint");
    const entryPoint = await EntryPoint.deploy();
    await entryPoint.waitForDeployment();
    console.log("✅ BundlerFreeEntryPoint deployed to:", await entryPoint.getAddress());
    
    // 4. 测试预编译合约连接
    console.log("\n4. Testing precompile connections...");
    
    // 测试质押预编译
    try {
        const [signer] = await hre.ethers.getSigners();
        const tx = await stakingPool.connect(signer).stake({
            value: hre.ethers.parseEther("100") // 质押 100 MCC
        });
        await tx.wait();
        console.log("✅ Staking precompile test successful");
    } catch (error) {
        console.log("❌ Staking precompile test failed:", error.message);
    }
    
    // 测试治理预编译
    try {
        const proposalTx = await stakingPool.createProposal(
            "Test Proposal",
            "This is a test governance proposal",
            { value: hre.ethers.parseEther("10000") } // 10000 MCC 押金
        );
        const receipt = await proposalTx.wait();
        console.log("✅ Governance precompile test successful");
    } catch (error) {
        console.log("❌ Governance precompile test failed:", error.message);
    }
    
    // 5. 输出部署总结
    console.log("\n📋 Deployment Summary:");
    console.log("=====================================");
    console.log("StakingPool:        ", await stakingPool.getAddress());
    console.log("CrossChainBridge:   ", await bridge.getAddress());
    console.log("BundlerFreeEntryPoint:", await entryPoint.getAddress());
    console.log("\n🔗 Precompile Addresses:");
    console.log("P256 Verification:   0x0000000000000000000000000000000000000100");
    console.log("Bech32 Encoding:     0x0000000000000000000000000000000000000400");
    console.log("Staking:            0x0000000000000000000000000000000000000800");
    console.log("Distribution:       0x0000000000000000000000000000000000000801");
    console.log("ICS20 Transfer:     0x0000000000000000000000000000000000000802");
    console.log("Governance:         0x0000000000000000000000000000000000000803");
    console.log("Slashing:           0x0000000000000000000000000000000000000804");
    console.log("Bank:               0x0000000000000000000000000000000000000805");
    console.log("ERC20 Module:       0x0000000000000000000000000000000000000806");
    console.log("WERC20 Wrapper:     0x0000000000000000000000000000000000000807");
    console.log("Account Abstraction: 0x0000000000000000000000000000000000000808");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
```

**预编译合约测试脚本**

```javascript
// test-precompiles.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MailChat Precompile Integration Tests", function () {
    let stakingPool, bridge, entryPoint;
    let owner, user1, user2;
    
    // 预编译合约地址
    const STAKING_PRECOMPILE = "0x0000000000000000000000000000000000000800";
    const GOVERNANCE_PRECOMPILE = "0x0000000000000000000000000000000000000803";
    const ICS20_PRECOMPILE = "0x0000000000000000000000000000000000000802";
    const AA_PRECOMPILE = "0x0000000000000000000000000000000000000808";
    
    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();
        
        // 部署测试合约
        const StakingPool = await ethers.getContractFactory("MailChatStakingPool");
        stakingPool = await StakingPool.deploy(
            "cosmosvaloper1test...",
            owner.address
        );
        
        const Bridge = await ethers.getContractFactory("MailChatBridge");
        bridge = await Bridge.deploy();
        
        const EntryPoint = await ethers.getContractFactory("BundlerFreeEntryPoint");
        entryPoint = await EntryPoint.deploy();
    });
    
    describe("Staking Precompile Integration", function () {
        it("Should allow users to stake through precompile", async function () {
            const stakeAmount = ethers.parseEther("100");
            
            await expect(
                stakingPool.connect(user1).stake({ value: stakeAmount })
            ).to.emit(stakingPool, "Staked");
            
            const userShares = await stakingPool.balanceOf(user1.address);
            expect(userShares).to.equal(stakeAmount);
        });
        
        it("Should compound rewards automatically", async function () {
            // 先质押
            await stakingPool.connect(user1).stake({ 
                value: ethers.parseEther("100") 
            });
            
            // 模拟有奖励可领取
            await expect(
                stakingPool.compoundRewards()
            ).to.emit(stakingPool, "RewardsDistributed");
        });
    });
    
    describe("Governance Precompile Integration", function () {
        it("Should create governance proposals", async function () {
            const depositAmount = ethers.parseEther("10000");
            
            const proposalId = await stakingPool.createProposal.staticCall(
                "Test Proposal",
                "Description",
                { value: depositAmount }
            );
            
            expect(proposalId).to.be.a('bigint');
        });
        
        it("Should vote on proposals", async function () {
            // 先创建提案
            const tx = await stakingPool.createProposal(
                "Test Proposal",
                "Description",
                { value: ethers.parseEther("10000") }
            );
            const receipt = await tx.wait();
            
            // 投票
            await expect(
                stakingPool.voteOnProposal(1, 1) // proposalId=1, option=Yes
            ).to.emit(stakingPool, "ProposalVoted");
        });
    });
    
    describe("ICS20 Precompile Integration", function () {
        it("Should initiate cross-chain transfers", async function () {
            const transferAmount = ethers.parseEther("50");
            
            await expect(
                bridge.connect(user1).bridgeToChain(
                    "channel-0",
                    "cosmos1recipient...",
                    "test memo",
                    { value: transferAmount }
                )
            ).to.emit(bridge, "CrossChainTransferInitiated");
        });
        
        it("Should handle batch transfers", async function () {
            const recipients = [
                "cosmos1recipient1...",
                "cosmos1recipient2..."
            ];
            const amounts = [
                ethers.parseEther("25"),
                ethers.parseEther("25")
            ];
            const totalAmount = ethers.parseEther("50");
            
            await expect(
                bridge.connect(user1).batchBridge(
                    "channel-0",
                    recipients,
                    amounts,
                    "batch memo",
                    { value: totalAmount }
                )
            ).to.not.be.reverted;
        });
    });
    
    describe("Account Abstraction Precompile Integration", function () {
        it("Should create smart accounts", async function () {
            const accountAddress = await entryPoint.createSmartAccount.staticCall(
                user1.address,
                "0x" // 空的初始化数据
            );
            
            expect(accountAddress).to.match(/^0x[a-fA-F0-9]{40}$/);
        });
        
        it("Should queue and execute user operations", async function () {
            const userOp = {
                sender: user1.address,
                nonce: 0,
                initCode: "0x",
                callData: "0x",
                callGasLimit: 100000,
                verificationGasLimit: 100000,
                preVerificationGas: 21000,
                maxFeePerGas: ethers.parseUnits("20", "gwei"),
                maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
                paymasterAndData: "0x",
                signature: "0x"
            };
            
            const executorTip = ethers.parseEther("0.01");
            const totalPayment = executorTip + BigInt(userOp.maxFeePerGas) * BigInt(userOp.verificationGasLimit);
            
            await expect(
                entryPoint.connect(user1).submitUserOperation(
                    userOp,
                    executorTip,
                    { value: totalPayment }
                )
            ).to.emit(entryPoint, "UserOperationQueued");
        });
    });
});
```

### 三、测试策略

#### 3.1 单元测试

```javascript
// test/Token.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MailChatToken", function () {
    let token, owner, addr1, addr2;
    
    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("MailChatToken");
        token = await Token.deploy();
    });
    
    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await token.owner()).to.equal(owner.address);
        });
        
        it("Should assign total supply to owner", async function () {
            const ownerBalance = await token.balanceOf(owner.address);
            expect(await token.totalSupply()).to.equal(ownerBalance);
        });
    });
    
    describe("Transactions", function () {
        it("Should transfer tokens between accounts", async function () {
            await token.transfer(addr1.address, 50);
            expect(await token.balanceOf(addr1.address)).to.equal(50);
        });
    });
});
```

#### 3.2 集成测试

```bash
#!/bin/bash
# integration_test.sh

# 启动本地网络
./local_node.sh -y &
NODE_PID=$!
sleep 10

# 运行测试套件
npm test

# 测试 IBC
hermes create channel --a-chain test1 --b-chain test2
hermes start &
HERMES_PID=$!

# 执行 IBC 测试
go test ./tests/ibc/...

# 清理
kill $NODE_PID $HERMES_PID
```

---

## 故障排除

### 常见问题与解决方案

#### 1. 节点同步问题

**问题**: 节点无法同步或同步缓慢

```bash
# 诊断
mailchatd status | jq '.SyncInfo'

# 解决方案
# 1. 使用状态同步
sed -i 's/enable = false/enable = true/' $CHAINDIR/config/config.toml

# 2. 使用快照
curl -L https://snapshots.example.com/latest.tar.gz | tar -xz -C $CHAINDIR/data

# 3. 增加对等节点
PEERS="node1@ip1:26656,node2@ip2:26656"
sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/" config.toml
```

#### 2. 交易失败

**问题**: 交易返回 "out of gas" 错误

```javascript
// 诊断和修复
async function fixGasIssue() {
    // 估算 gas
    const estimatedGas = await contract.estimateGas.method(params);
    
    // 添加 20% 缓冲
    const gasLimit = estimatedGas * 120n / 100n;
    
    // 获取当前 gas 价格
    const gasPrice = await provider.getFeeData();
    
    // 发送交易
    const tx = await contract.method(params, {
        gasLimit: gasLimit,
        maxFeePerGas: gasPrice.maxFeePerGas,
        maxPriorityFeePerGas: gasPrice.maxPriorityFeePerGas
    });
}
```

#### 3. RPC 连接问题

**问题**: 无法连接到 JSON-RPC

```bash
# 检查端口
netstat -tlnp | grep 8545

# 检查配置
grep -A 10 "json-rpc" $CHAINDIR/config/app.toml

# 重启服务
systemctl restart mailchatd

# 测试连接
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

#### 4. 验证人被 Jail

**问题**: 验证人因错过区块被监禁

```bash
# 检查状态
mailchatd query staking validator $VALIDATOR_ADDR | grep jailed

# 解除监禁
mailchatd tx slashing unjail \
  --from=validator \
  --chain-id=$CHAINID \
  --gas=200000 \
  --gas-prices=0.025amcc

# 预防措施
# 1. 监控脚本
*/5 * * * * /scripts/check_validator.sh

# 2. 设置告警
# 3. 使用哨兵节点架构
```

### 性能调优检查清单

```yaml
数据库:
  ✓ 启用 LevelDB 压缩
  ✓ 调整缓存大小
  ✓ 定期修剪状态

网络:
  ✓ 优化对等节点数量
  ✓ 使用私有哨兵节点
  ✓ 配置防火墙规则

共识:
  ✓ 调整超时参数
  ✓ 优化内存池大小
  ✓ 启用交易索引

监控:
  ✓ Prometheus 指标
  ✓ Grafana 仪表板
  ✓ 日志聚合
```

---

## 参考资源

### 官方文档
- [Cosmos SDK 文档](https://docs.cosmos.network/)
- [Ethereum JSON-RPC 规范](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [IBC 协议规范](https://ibc.cosmos.network/)
- [Tendermint Core](https://docs.tendermint.com/)

### 开发工具
- [Hardhat](https://hardhat.org/)
- [Truffle Suite](https://trufflesuite.com/)
- [CosmJS](https://cosmos.github.io/cosmjs/)
- [Hermes Relayer](https://hermes.informal.systems/)

---

## 版本历史

| 版本 | 日期 | 主要更新 |
|------|------|----------|
| v0.1.0 | 2025-08 | - 初始版本<br>- 基础 EVM 支持<br>- IBC 集成 |
| v0.2.0 | 计划中 | - 性能优化<br>- 新预编译合约<br>- 改进的状态同步 |

---

*本文档持续更新中。最新版本请访问 [官方文档](https://docs.mailchat.chain)*