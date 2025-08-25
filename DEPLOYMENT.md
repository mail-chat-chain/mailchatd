# MailChat 部署流程文档

本文档详细描述了不使用 `local_node.sh` 脚本的手动部署流程，适用于生产环境或需要自定义配置的场景。

## 前置要求

- Go 1.21+ 已安装
- `jq` 命令行工具已安装
- 足够的磁盘空间和内存
- 网络连接稳定

## 1. 编译二进制文件

### 开发环境编译
```bash
# 编译到构建目录
make build

# 安装到系统 PATH
make install

# Linux 交叉编译（如需要）
make build-linux
```

### 调试版本编译
```bash
# 编译调试版本（禁用优化，保留调试信息）
make install COSMOS_BUILD_OPTIONS=nooptimization,nostrip
```

## 2. 环境变量配置

```bash
# 基本配置
export CHAINID="26000"                    # 链 ID，可自定义
export MONIKER="mailchat-node"            # 节点名称
export CHAINDIR="$HOME/.mailchatd"       # 节点数据目录
export KEYRING="test"                     # 密钥环类型，生产环境建议使用 "file"
export KEYALGO="eth_secp256k1"           # 密钥算法

# 路径配置
export CONFIG_TOML="$CHAINDIR/config/config.toml"
export APP_TOML="$CHAINDIR/config/app.toml"
export GENESIS="$CHAINDIR/config/genesis.json"
export TMP_GENESIS="$CHAINDIR/config/tmp_genesis.json"
```

## 3. 节点初始化

```bash
# 初始化节点
mailchatd init "$MONIKER" --chain-id "$CHAINID" --home "$CHAINDIR"

# 配置客户端默认设置
mailchatd config set client chain-id "$CHAINID" --home "$CHAINDIR"
mailchatd config set client keyring-backend "$KEYRING" --home "$CHAINDIR"
```

## 4. 密钥管理

### 创建新账户
```bash
# 验证者账户
mailchatd keys add validator --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"

# 用户账户
mailchatd keys add user1 --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
mailchatd keys add user2 --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"
```

### 查看账户信息
```bash
# 列出所有账户
mailchatd keys list --home "$CHAINDIR"

# 查看特定账户
mailchatd keys show validator --home "$CHAINDIR"
mailchatd keys show validator --address --home "$CHAINDIR"
```

## 5. 创世文件配置

创世文件 `genesis.json` 是区块链网络的初始状态配置，包含了链的基本参数、初始账户余额、治理参数等。以下是手动修改各个参数的详细说明。

### 5.1 基础代币配置

#### Staking 模块配置
```bash
# 手动修改方式：
# 1. 使用文本编辑器打开 $CHAINDIR/config/genesis.json
# 2. 找到 app_state.staking.params.bond_denom 字段
# 3. 将值改为 "amcc"

# 命令行修改方式：
jq '.app_state["staking"]["params"]["bond_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `bond_denom`: 质押代币的基本单位
- 作用：验证者需要使用此代币进行质押来参与网络共识
- 影响：所有与质押相关的操作（委托、取消委托、奖励分发）都使用此代币

#### 治理模块配置
```bash
# 治理提案最小押金代币
jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# 治理参数中的最小押金（新版本）
jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# 加急提案最小押金
jq '.app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `min_deposit`: 提交提案需要的最小押金数量和代币类型
- `expedited_min_deposit`: 加急提案需要的押金（通常更高）
- 作用：防止垃圾提案，确保提案者有经济激励认真考虑提案
- 影响：提案者必须押金足够数量的指定代币才能提交提案

#### EVM 模块配置
```bash
# EVM 交易使用的代币
jq '.app_state["evm"]["params"]["evm_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `evm_denom`: EVM 环境中用于支付 gas 费用的代币
- 作用：确定以太坊虚拟机交易的手续费代币类型
- 影响：所有智能合约调用和 EVM 交易都使用此代币支付 gas

#### 铸币模块配置
```bash
# 通胀奖励使用的代币
jq '.app_state["mint"]["params"]["mint_denom"]="amcc"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `mint_denom`: 网络通胀时铸造的代币类型
- 作用：定义区块奖励和通胀奖励的代币类型
- 影响：验证者和委托者获得的通胀奖励将是此类型的代币

### 5.2 代币元数据配置
```bash
# 手动编辑示例：
# 在 genesis.json 中找到 app_state.bank.denom_metadata 数组，添加或修改：
{
  "description": "The native staking token for mailchatd.",
  "denom_units": [
    {"denom": "amcc", "exponent": 0, "aliases": ["attomcc"]},
    {"denom": "mcc", "exponent": 18, "aliases": []}
  ],
  "base": "amcc",
  "display": "mcc", 
  "name": "Mail Chat Coin",
  "symbol": "MCC",
  "uri": "",
  "uri_hash": ""
}

# 命令行方式：
jq '.app_state["bank"]["denom_metadata"]=[{
  "description":"The native staking token for mailchatd.",
  "denom_units":[
    {"denom":"amcc","exponent":0,"aliases":["attomcc"]},
    {"denom":"mcc","exponent":18,"aliases":[]}
  ],
  "base":"amcc",
  "display":"mcc",
  "name":"Mail Chat Coin",
  "symbol":"MCC",
  "uri":"",
  "uri_hash":""
}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `base`: 最小单位代币名称（1 amcc = 10^-18 mcc）
- `display`: 用户界面显示的代币单位
- `exponent`: 单位转换的指数（18 表示 10^18 的转换比例）
- `name/symbol`: 代币的全名和简称
- 作用：定义代币的显示格式和单位转换关系
- 影响：钱包和用户界面如何显示代币数量和单位

### 代币元数据配置
```bash
jq '.app_state["bank"]["denom_metadata"]=[{
  "description":"The native staking token for mailchatd.",
  "denom_units":[
    {"denom":"amcc","exponent":0,"aliases":["attomcc"]},
    {"denom":"mcc","exponent":18,"aliases":[]}
  ],
  "base":"amcc",
  "display":"mcc",
  "name":"Mail Chat Coin",
  "symbol":"MCC",
  "uri":"",
  "uri_hash":""
}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

### 5.3 EVM 预编译合约配置
```bash
# 手动编辑方式：
# 在 genesis.json 中找到 app_state.evm.params.active_static_precompiles 数组
# 添加以下地址：

# 命令行方式：
jq '.app_state["evm"]["params"]["active_static_precompiles"]=[
  "0x0000000000000000000000000000000000000100",
  "0x0000000000000000000000000000000000000400",
  "0x0000000000000000000000000000000000000800",
  "0x0000000000000000000000000000000000000801",
  "0x0000000000000000000000000000000000000802",
  "0x0000000000000000000000000000000000000803",
  "0x0000000000000000000000000000000000000804",
  "0x0000000000000000000000000000000000000805",
  "0x0000000000000000000000000000000000000806",
  "0x0000000000000000000000000000000000000807"
]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**预编译合约地址说明**：
- `0x100`: Bech32 地址转换预编译（Cosmos ↔ Ethereum 地址格式转换）
- `0x400`: Bank 模块预编译（代币转账、余额查询等）
- `0x800`: Staking 模块预编译（质押、委托操作）
- `0x801`: Distribution 模块预编译（奖励分发、提取操作）
- `0x802`: Gov 模块预编译（治理提案、投票）
- `0x803`: ICS20 预编译（跨链转账）
- `0x804`: Werc20 预编译（ERC20 代币包装）
- `0x805`: ERC20 模块预编译（代币对管理）
- `0x806`: P256 验证预编译（椭圆曲线签名验证）
- `0x807`: Slashing 模块预编译（惩罚机制）

**参数意义**：
- 作用：定义在 EVM 环境中可用的系统级预编译合约
- 影响：智能合约可以通过这些地址调用 Cosmos SDK 模块功能
- 重要性：实现 EVM 和 Cosmos 生态的桥接，让以太坊 DApp 能访问 Cosmos 功能

### 5.4 ERC20 代币对配置
```bash
# 手动编辑方式：
# 在 genesis.json 中：
# 1. 找到 app_state.erc20.native_precompiles 数组
# 2. 找到 app_state.erc20.token_pairs 数组

# 启用原生代币预编译
jq '.app_state.erc20.native_precompiles=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# 配置代币对
jq '.app_state.erc20.token_pairs=[{
  contract_owner:1,
  erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
  denom:"amcc",
  enabled:true
}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `native_precompiles`: 原生代币在 EVM 中的预编译地址
- `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`: 以太坊社区约定的原生代币地址
- `token_pairs`: 定义 Cosmos 代币与 ERC20 代币的映射关系
- `contract_owner`: 代币合约的所有者类型（1=模块拥有，0=外部拥有）
- 作用：让原生 Cosmos 代币可以在 EVM 环境中作为 ERC20 代币使用
- 影响：用户可以在以太坊钱包中看到和使用 Cosmos 代币

### 5.5 区块和共识参数配置
```bash
# 手动编辑方式：
# 在 genesis.json 中找到 consensus.params.block.max_gas 字段

# 设置区块最大 gas 限制
jq '.consensus.params.block.max_gas="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
```

**参数意义**：
- `max_gas`: 单个区块能包含的最大 gas 数量
- 作用：限制区块大小，防止区块过大影响网络性能
- 影响：决定了网络的交易吞吐量上限
- 建议值：
  - 开发环境: 10,000,000 (10M)
  - 测试网: 20,000,000 (20M)  
  - 主网: 根据网络性能和需求调整

## 6. 网络配置优化

网络配置文件位于 `$CHAINDIR/config/config.toml` 和 `$CHAINDIR/config/app.toml`。以下是各个参数的详细说明和手动修改方法。

### 6.1 共识时序参数配置

**配置文件位置**: `$CHAINDIR/config/config.toml`

#### 手动编辑方式
使用文本编辑器打开 `config.toml`，找到 `[consensus]` 部分，修改以下参数：

```toml
[consensus]
# 提案阶段超时时间
timeout_propose = "2s"          # 默认: "3s"
timeout_propose_delta = "200ms" # 默认: "500ms"

# 预投票阶段超时时间
timeout_prevote = "500ms"       # 默认: "1s"
timeout_prevote_delta = "200ms" # 默认: "500ms"

# 预提交阶段超时时间
timeout_precommit = "500ms"     # 默认: "1s"
timeout_precommit_delta = "200ms" # 默认: "500ms"

# 提交阶段超时时间
timeout_commit = "1s"           # 默认: "5s"

# 广播交易超时时间
timeout_broadcast_tx_commit = "5s" # 默认: "10s"
```

#### 命令行批量修改方式
```bash
# macOS 使用
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"
    sed -i '' 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "5s"/g' "$CONFIG_TOML"
else
    # Linux 使用
    sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
    sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
    sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
    sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
    sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"
    sed -i 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "5s"/g' "$CONFIG_TOML"
fi
```

**参数意义详解**：

1. **timeout_propose**: 验证者提出新区块的超时时间
   - 作用：给验证者足够时间收集交易并构建区块
   - 开发环境：较短时间加快测试速度
   - 生产环境：考虑网络延迟和负载

2. **timeout_propose_delta**: 每轮提案超时时间的增量
   - 作用：在网络拥堵时逐渐增加超时时间
   - 防止网络问题导致的无限重试

3. **timeout_prevote/timeout_precommit**: 投票阶段的超时时间
   - 作用：给验证者足够时间广播和接收投票
   - 影响：过短可能导致投票丢失，过长会降低出块速度

4. **timeout_commit**: 等待提交的时间
   - 作用：确保所有验证者都能收到最终提交
   - 开发环境：1s 快速测试
   - 生产环境：3-5s 保证网络稳定性

**环境建议值**：
- **开发环境**: 快速出块，适合测试
- **测试网**: 中等速度，模拟真实网络条件
- **主网**: 保守设置，确保网络稳定性

### 6.2 监控和 API 配置

#### Prometheus 监控配置

**配置文件位置**: `$CHAINDIR/config/config.toml`

**手动编辑方式**：
找到 `[instrumentation]` 部分，修改以下参数：

```toml
[instrumentation]
# 启用 Prometheus 监控端点
prometheus = true                    # 默认: false
prometheus_listen_addr = ":26660"    # 监控端点地址
max_open_connections = 3             # 最大连接数
namespace = "cometbft"               # 指标命名空间
```

#### API 服务配置

**配置文件位置**: `$CHAINDIR/config/app.toml`

**手动编辑方式**：
找到各个 API 部分，修改以下参数：

```toml
# gRPC 服务配置
[grpc]
enable = true                        # 默认: true
address = "localhost:9090"           # gRPC 端点

# gRPC-Web 服务配置  
[grpc-web]
enable = true                        # 默认: false
address = "localhost:9091"           # gRPC-Web 端点

# REST API 配置
[api]
enable = true                        # 默认: false
swagger = true                       # 启用 Swagger 文档
address = "tcp://localhost:1317"     # REST API 端点
max-open-connections = 1000          # 最大连接数

# EVM JSON-RPC 配置
[json-rpc]
enable = true                        # 默认: true
address = "0.0.0.0:8545"            # JSON-RPC 端点
ws-address = "0.0.0.0:8546"         # WebSocket 端点
```

#### 命令行批量修改方式
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 配置
    # 启用 Prometheus 监控
    sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"
    
    # 启用各种 API 端点（开发环境）
    sed -i '' 's/enable = false/enable = true/g' "$APP_TOML"
    sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
    
    # 配置 Prometheus 数据保留时间（可选）
    sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time = 1000000000000/g' "$APP_TOML"
else
    # Linux 配置
    sed -i 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"
    sed -i 's/enable = false/enable = true/g' "$APP_TOML"
    sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
    sed -i 's/prometheus-retention-time = "0"/prometheus-retention-time = "1000000000000"/g' "$APP_TOML"
fi
```

**参数意义详解**：

1. **Prometheus 监控**：
   - 作用：收集节点性能指标，用于监控和告警
   - 指标包括：区块高度、交易数量、内存使用、网络连接等
   - 端口：默认 26660

2. **API 端点说明**：
   - **gRPC** (端口 9090)：高性能的 RPC 调用
   - **REST API** (端口 1317)：标准 HTTP API
   - **JSON-RPC** (端口 8545)：以太坊兼容的 RPC 接口
   - **WebSocket** (端口 8546)：实时事件订阅

3. **安全注意事项**：
   - 生产环境应限制 API 访问 IP
   - 考虑使用反向代理和 SSL 加密
   - 监控 API 调用频率和资源使用

### 6.3 治理参数配置

**配置文件位置**: `$CHAINDIR/config/genesis.json`

#### 手动编辑方式
在 `genesis.json` 中找到 `app_state.gov.params` 部分，修改以下参数：

```json
{
  "app_state": {
    "gov": {
      "params": {
        "max_deposit_period": "30s",      // 默认: "172800s" (48小时)
        "voting_period": "30s",          // 默认: "172800s" (48小时)  
        "expedited_voting_period": "15s", // 默认: "86400s" (24小时)
        "min_deposit": [
          {"denom": "amcc", "amount": "10000000"}
        ],
        "expedited_min_deposit": [
          {"denom": "amcc", "amount": "50000000"}
        ]
      }
    }
  }
}
```

#### 命令行修改方式
```bash
# 缩短提案周期用于开发测试
sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$GENESIS"
sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$GENESIS"
sed -i.bak 's/"expedited_voting_period": "86400s"/"expedited_voting_period": "15s"/g' "$GENESIS"
```

**参数意义详解**：

1. **max_deposit_period**: 提案押金收集期限
   - 作用：提案提交后，社区成员可以继续添加押金的时间窗口
   - 开发环境：30s 快速测试
   - 生产环境：172800s (48小时) 给社区足够时间

2. **voting_period**: 正常提案投票期
   - 作用：验证者和委托者对提案进行投票的时间
   - 影响：时间过短可能导致参与度低，过长延缓治理决策

3. **expedited_voting_period**: 加急提案投票期
   - 作用：重要或紧急提案的快速投票通道
   - 要求：通常需要更高的押金和投票阈值

### 6.4 数据修剪配置

**配置文件位置**: `$CHAINDIR/config/app.toml`

#### 手动编辑方式
找到 `[base]` 部分，修改以下参数：

```toml
[base]
# 修剪策略
pruning = "custom"              # 选项: "default", "nothing", "everything", "custom"
pruning-keep-recent = "100"     # 保留最近的区块数量
pruning-interval = "10"         # 修剪间隔（每N个区块执行一次修剪）
```

#### 命令行修改方式
```bash
# 自定义修剪设置
sed -i.bak 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "100"/g' "$APP_TOML"
sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/g' "$APP_TOML"
```

**修剪策略说明**：

1. **pruning = "default"**: 
   - 保留最近 100,000 个区块，每 500 个区块修剪一次
   - 适合大多数节点

2. **pruning = "nothing"**:
   - 不修剪任何数据，保留完整历史
   - 适合归档节点和区块浏览器

3. **pruning = "everything"**:
   - 只保留最近 2 个区块，每个区块都修剪
   - 最节省存储空间，但丢失历史数据

4. **pruning = "custom"**:
   - 自定义修剪参数
   - `pruning-keep-recent`: 保留的最近区块数量
   - `pruning-interval`: 修剪执行间隔

**存储空间影响**：
- **不修剪**: 数据量持续增长，需要大量存储空间
- **轻度修剪**: 保留一定历史，平衡存储和功能
- **积极修剪**: 最小存储需求，但限制历史查询能力

## 7. 账户余额分配

```bash
# 为验证者账户分配大量代币（验证者需要质押代币）
mailchatd genesis add-genesis-account validator 100000000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"

# 为用户账户分配测试代币
mailchatd genesis add-genesis-account user1 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"
mailchatd genesis add-genesis-account user2 1000000000000000000000amcc --keyring-backend "$KEYRING" --home "$CHAINDIR"

# 可以添加更多账户...
```

## 8. 验证者设置

```bash
# 创建验证者创世交易
mailchatd genesis gentx validator 1000000000000000000000amcc \
  --gas-prices 10000000amcc \
  --keyring-backend "$KEYRING" \
  --chain-id "$CHAINID" \
  --home "$CHAINDIR"

# 收集所有创世交易
mailchatd genesis collect-gentxs --home "$CHAINDIR"

# 验证创世文件的正确性
mailchatd genesis validate-genesis --home "$CHAINDIR"
```

## 9. 启动节点

### 基础启动
```bash
mailchatd start \
  --log_level info \
  --minimum-gas-prices=0.0001amcc \
  --home "$CHAINDIR" \
  --json-rpc.api eth,txpool,personal,net,debug,web3 \
  --chain-id "$CHAINID"
```

### 后台启动
```bash
nohup mailchatd start \
  --log_level info \
  --minimum-gas-prices=0.0001amcc \
  --home "$CHAINDIR" \
  --json-rpc.api eth,txpool,personal,net,debug,web3 \
  --chain-id "$CHAINID" > "$CHAINDIR/node.log" 2>&1 &
```

### 使用 systemd 服务（推荐生产环境）
创建服务文件 `/etc/systemd/system/mailchatd.service`：
```ini
[Unit]
Description=MailChat Node
After=network.target

[Service]
Type=simple
User=mailchat
WorkingDirectory=/home/mailchat
ExecStart=/usr/local/bin/mailchatd start --log_level info --minimum-gas-prices=0.0001amcc --home /home/mailchat/.mailchatd --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id 26000
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl enable mailchatd
sudo systemctl start mailchatd
sudo systemctl status mailchatd
```

## 10. 验证部署

### 检查节点状态
```bash
# 检查节点同步状态
mailchatd status --home "$CHAINDIR"

# 查看账户余额
mailchatd query bank balances $(mailchatd keys show validator -a --home "$CHAINDIR") --home "$CHAINDIR"

# 检查验证者状态
mailchatd query staking validator $(mailchatd keys show validator --bech val -a --home "$CHAINDIR") --home "$CHAINDIR"
```

### 测试 JSON-RPC 端点
```bash
# 测试 HTTP RPC
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545

# 测试余额查询
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x...", "latest"],"id":1}' http://localhost:8545
```

## 生产环境安全配置

### 密钥安全
```bash
# 使用 file 类型密钥环并设置密码
export KEYRING="file"

# 备份验证者私钥
cp "$CHAINDIR/config/priv_validator_key.json" /secure/backup/location/

# 设置适当的文件权限
chmod 600 "$CHAINDIR/config/priv_validator_key.json"
chmod 600 "$CHAINDIR/config/node_key.json"
```

### 网络安全
```bash
# 限制 RPC 访问（在 config.toml 中）
laddr = "tcp://127.0.0.1:26657"  # 仅本地访问

# 限制 JSON-RPC 访问（在 app.toml 中）
address = "127.0.0.1:8545"       # 仅本地访问

# 配置防火墙
sudo ufw allow 26656/tcp         # P2P 端口
sudo ufw allow from trusted_ip to any port 26657  # RPC 端口（仅信任的 IP）
sudo ufw allow from trusted_ip to any port 8545   # JSON-RPC 端口（仅信任的 IP）
```

### 监控配置
```bash
# 启用详细日志
--log_level debug

# 配置日志轮转（使用 logrotate）
echo "/path/to/mailchat/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    create 644 mailchat mailchat
    postrotate
        systemctl reload mailchatd
    endscript
}" | sudo tee /etc/logrotate.d/mailchatd
```

## 故障排除

### 常见问题
1. **创世文件验证失败**：检查 JSON 格式和必需字段
2. **密钥环错误**：确保密钥环类型和路径正确
3. **端口冲突**：检查 26656、26657、8545 端口是否被占用
4. **权限问题**：确保节点数据目录有适当权限

### 日志分析
```bash
# 查看最新日志
tail -f "$CHAINDIR/node.log"

# 搜索错误信息
grep -i error "$CHAINDIR/node.log"

# 查看共识日志
grep -i consensus "$CHAINDIR/node.log"
```

### 数据重置
```bash
# 重置节点数据（保留配置）
mailchatd tendermint unsafe-reset-all --home "$CHAINDIR"

# 完全重新开始
rm -rf "$CHAINDIR"
# 然后重新执行初始化流程
```

## 钱包连接

### MetaMask 配置
- 网络名称：MailChat Local
- RPC URL：http://localhost:8545
- 链 ID：26000
- 货币符号：MCC
- 区块浏览器 URL：（可选）

### 测试交易
```bash
# 发送代币交易
mailchatd tx bank send validator user1 1000000000000000000amcc \
  --gas-prices 0.0001amcc \
  --gas auto \
  --gas-adjustment 1.5 \
  --keyring-backend "$KEYRING" \
  --home "$CHAINDIR" \
  --chain-id "$CHAINID"
```

## 升级和维护

### 软件升级
```bash
# 停止节点
sudo systemctl stop mailchatd

# 备份数据
cp -r "$CHAINDIR" "$CHAINDIR.backup.$(date +%Y%m%d)"

# 更新二进制文件
make install

# 重启节点
sudo systemctl start mailchatd
```

### 定期维护
- 定期备份验证者私钥
- 监控磁盘空间使用情况
- 检查日志中的错误信息
- 保持软件版本更新

---

*此文档提供了完整的手动部署流程，可根据具体需求进行调整和定制。*