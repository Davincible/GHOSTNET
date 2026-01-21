

Realtime API

    Overview of the Changes
    Querying Account and Chain States
        Example
    Querying Transactions
        Example
    eth_subscribe over WebSocket
        Logs
        State Changes
        Mini Blocks
    Sending and Confirming Transactions in One Round Trip
        Overview
        Example
    Paginated Log Queries with Cursors
        Overview
        Example

MegaETH executes transactions as soon as they arrive at the sequencer. The sequencer emits preconfirmations and execution results of the transactions within 10 milliseconds of their arrival at the sequencer.

Such information is exposed through MegaETH’s Realtime API, an extension to Ethereum JSON-RPC API optimized for low-latency access. This API queries against the most recent mini block. In other words, receipts and state changes associated with a transaction are reflected in this API as soon as the transaction is packaged into a mini block, which usually happens within 10 milliseconds of its arrival at the sequencer. In comparison, the vanilla Ethereum JSON-RPC API queries against the most recent EVM block, which leads to much longer delay before execution results are reflected.

It is important to note that mini blocks in MegaETH are preconfirmed by the sequencer just like EVM blocks are. The sequencer makes as much effort not to roll back mini blocks as it does EVM blocks. Thus, results returned by the Realtime API still fall under the preconfirmation guarantee by the sequencer.

This document specifies the Realtime API. Note that the Realtime API is an evolving standard. Additional functionalities will be added to the API based on feedbacks. This document will be kept up to date.
Overview of the Changes

The Realtime API introduces three types of changes to the vanilla Ethereum JSON-RPC API:

    Most methods that query chain and account states return values as of the most recent mini block, when invoked with pending or latest as the block tag.
    Most methods that query transaction data are able to “see” a transaction and return results as soon as the transaction of interest is packaged into a mini block.
    eth_subscribe, when invoked over WebSocket, streams transaction logs, state changes, and block content as soon as the corresponding mini block is produced.
    realtime_sendRawTransaction submits a transaction and returns the receipt in a single call — without requiring polling.
    eth_getLogsWithCursor supports paginated log queries using a cursor, allowing applications to retrieve large datasets incrementally and reliably.

Querying Account and Chain States

The following API methods that query account and chain states, when invoked with pending or latest as the block tag, return results up to the most recent mini block.
Method
eth_getBalance
eth_getStorageAt
eth_getTransactionCount
eth_getCode
eth_call
eth_callMany
eth_createAccessList
eth_estimateGas
Example

At 5pm, the height of the most recent mini block is 10000, and the height of the most recent EVM block is 100. At this point, Alice’s account has a balance of 10 Ether.

At 100 milliseconds past 5pm, the height of the most recent mini block is 10010, and the height of the most recent EVM block is still 100. Now, Alice sends a transaction that transfers 1 Ether to Bob. This transaction will decrease her account balance by 1 Ether.

At 110 milliseconds past 5pm, the transaction is picked up and executed by the sequencer, and packaged into the mini block at height 10011. Now, Bob invokes eth_getBalance on Alice’s account with latest as the block tag; he get a response of 9 Ether, because the transaction has been packaged into a mini block and is thus reflected in the Realtime API. However, Charlie, who makes the same query with 100 as the block tag, still sees 10 Ether, because the transaction has not been packaged into an EVM block, which will not happen until 1 second past 5pm.
Querying Transactions

The following API methods that query transaction data are able to locate a transaction in the database and return results as soon as the transaction is packaged into a mini block. No special parameters are needed when invoking the methods.
Method
eth_getTransactionByHash
eth_getTransactionReceipt
Example

Continuing the previous example, Alice invokes eth_getTransactionReceipt on her transaction at 110 milliseconds past 5pm. The API responds with the correct receipt, even though no EVM block has been produced since she sent her transaction. This is because her transaction is already packaged into the mini block at height 10011 and the Realtime API can thus see the transaction.
eth_subscribe over WebSocket

When invoked over WebSocket, eth_subscribe streams data as soon as the corresponding mini block is produced. This is the mechanism to get transaction preconfirmation and execution results with the minimum amount of latency. As a reminder, please call eth_unsubscribe when a subscription is no longer needed.

Note: WebSocket connections require periodic client activity to remain open. Clients should send eth_chainId at least once every 30 seconds to keep the WebSocket connection alive. Idle connections may be closed by the server.
Logs

When both startBlock and endBlock are set to pending, the API returns logs as soon as transactions are packaged into mini blocks. The following query is an example.

{
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": [
        "logs",
        {
            "fromBlock": "pending",
            "toBlock": "pending"
        }
    ],
    "id": 83
}

It is also possible to filter the logs by contract addresses and topics. Here is an example.

{
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": [
        "logs",
        {
            "address": "0x8320fe7702b96808f7bbc0d4a888ed1468216cfd",
            "topics": ["0xd78a0cb8bb633d06981248b816e7bd33c2a35a6089241d099fa519e361cab902"],
            "fromBlock": "pending",
            "toBlock": "pending"
        }
    ],
    "id": 83
}

The schema of each log entry is the same as in eth_getLogs.
State Changes

stateChanges is a new type of subscription that streams state changes of an account as soon as the transactions making the changes are packaged into mini blocks. It takes a list of account addresses to monitor as a parameter. Here is an example.

{
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": [
        "stateChanges",
        ["0x2ef038991d64c72646d4f06ba78d93f4f1654e3f"]
    ],
    "id": 83
}

Here is an example of the response. It shows the latest account balance, nonce, and values of storage slots that are changed. The schema is as the following.

{
    "address": Address, // The address of the account that is changed.
    "nonce": number, // The latest nonce of the account.
    "balance": U256, // The latest balance of the account.
    "storage": { // Updated storage slots and new values of the account.
       U256: U256,
       ... 
    }
}

Here is an example.

{
    "address": "0x2ef038991d64c72646d4f06ba78d93f4f1654e3f",
    "nonce": 1,
    "balance": "0x16345785d8a0000",
    "storage": {
    "0xb6318d15e99499c465cc5e3d630975bf37b5641a8beb2614b018219310f4ea12": "0x68836e425f5",
    "0xbf0f571b7368c19b53ab5ef0ff767ed8e0aef55a462778a6119b7871b017ce8f": "0x71094412456b0"
    }
}

Mini Blocks

miniBlocks is a new type of subscription that streams mini blocks as they are produced. Here is an example.

{
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": [
        "miniBlocks"
    ],
    "id": 83
}

The returned mini blocks use the following schema.

{
     "block_number": HexString, // The block number of that EVM block that this mini-block belongs to
     "block_timestamp": HexString, // Timestamp of the EVM block
     "index": HexString, // Index of this mini-block in the EVM block
     "mini_block_number": HexString, // The number of this mini-block in blockchain history
     "mini_block_timestamp": HexString, // The timestamp when this mini-block is created. Unix timestamp in microseconds.
     "gas_used": HexString, // Gas used inside this mini-block
     "transactions": [ ... ], // Transactions included in this mini-block. The schema of each transaction is the same as `eth_getTransactionByHash`.
     "receipts": [ ... ] // Receipts of the transactions in this mini-block. The schema of each receipt is the same as `eth_getTransactionReceipt`.
}

Sending and Confirming Transactions in One Round Trip
Overview

realtime_sendRawTransaction simplifies realtime dApp development by returning the transaction receipt directly, without requiring polling eth_getTransactionReceipt. It accepts the same parameters as eth_sendRawTransaction but waits for the transaction to be executed and returns its receipt as the response. This method times out after 10 seconds, in which case it returns a realtime transaction expired error, indicating that the user should revert to querying eth_getTransactionReceipt.
Example

realtime_sendRawTransaction is a drop-in replacement of eth_sendRawTransaction.

{
  "jsonrpc": "2.0",
  "method": "realtime_sendRawTransaction",
  "params": [
    "0x<hex-encoded-signed-tx>"
  ],
  "id": 1
}

If the submitted transaction is executed within 10 seconds, it returns the receipt of the executed transaction.

{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "blockHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "blockNumber": "0x10",
    "contractAddress": null,
    "cumulativeGasUsed": "0x11dde",
    "effectiveGasPrice": "0x23ebdf",
    "from": "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
    "gasUsed": "0x5208",
    "logs": [],
    "logsBloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "status": "0x1",
    "to": "0xa7b8c275b3dde39e69a5c0ffd9f34f974364941a",
    "transactionHash": "0xf98a6b5de84ee59666d0ff3d8c361f308c3a22fc0bb94466810777d60a3ed7a7",
    "transactionIndex": "0x1",
    "type": "0x0"
  }
}

If the transaction is not executed within 10 seconds, e.g., because of congestion at the sequencer, it returns an error.

{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32000,
    "message": "realtime transaction expired"
  }
}

Paginated Log Queries with Cursors
Overview

eth_getLogsWithCursor is an enhanced version of eth_getLogs that adds support for pagination via a cursor. This allows applications to query large sets of logs while gracefully handing execution or memory limits on the RPC server. When a query exceeds server-side resource caps, the server returns a partial result and a cursor that marks where it left off. The client can then continue the query from that point.

This method accepts the same parameters as eth_getLogs, with an additional optional cursor, which is an opaque string. If the query is too large and hits the server-side caps, it returns a partial list of logs and a cursor pointing to the next log to fetch. Clients can resume the query using the provided cursor. Absence of a cursor in the request indicates that the server should start the query at fromBlock as usual. Absence of a returned cursor indicates the query is complete. The cursor is derived from (blockNumber + logIndex) of the last log in the current batch, but users should treat it as an opaque string.
Example

To send an initial request, start with a standard eth_getLogs-style query. Set fromBlock and toBlock (or blockHash) and do not include a cursor.

{
  "jsonrpc": "2.0",
  "method": "eth_getLogsWithCursor",
  "params": [
    {
      "fromBlock": "0x100",
      "toBlock": "0x200",
      "address": "0x1234567890abcdef1234567890abcdef12345678",
      "topics": ["0xddf252ad..."]
    }
  ],
  "id": 1
}

If the server reaches its processing limit (e.g. max logs or execution time), it will return the logs retrieved so far and include a cursor indicating the last log processed.

{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "logs": [
      {
        "address": "0x1234567890abcdef1234567890abcdef12345678",
        "blockNumber": "0x101",
        "logIndex": "0x0",
        "topics": ["0xddf252ad..."],
        "data": "0x...",
        "transactionHash": "0x...",
        "transactionIndex": "0x0",
        "blockHash": "0x...",
        "removed": false
      }
    ],
    "cursor": "0x0000010100000000"  
  }
}

The client should submit a second request with the same filter (e.g. address, topics, block range) and the cursor from the previous response (mandatory). The server will resume the query from where it left off.

{
  "jsonrpc": "2.0",
  "method": "eth_getLogsWithCursor",
  "params": [
    {
      "fromBlock": "0x100",
      "toBlock": "0x200",
      "address": "0x1234567890abcdef1234567890abcdef12345678",
      "topics": ["0xddf252ad..."],
      "cursor": "0x0000010100000000"
    }
  ],
  "id": 2
}

When the server returns a response without a cursor, it means that all matching logs have been retrieved and no further requests are needed

{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "logs": [
      {
        "address": "0x1234567890abcdef1234567890abcdef12345678",
        "blockNumber": "0x102",
        "logIndex": "0x3",
        "topics": ["0xddf252ad..."],
        "data": "0x...",
        "transactionHash": "0x...",
        "transactionIndex": "0x2",
        "blockHash": "0x...",
        "removed": false
      }
    ]
    // No cursor field — query is complete
  }
}

---
 
# Infrastructure

MegaETH solved the slow-chain problem. Next is the slow-infra problem. Oracles, indexers, apps—real-time chains demand innovation on traditional tools before users can *feel* real-time.

### The Infrastructure Challenge

Traditional blockchain infrastructure assumes multi-second block times:

* **RPCs** poll for receipts every few seconds
* **Indexers** batch process blocks periodically
* **Oracles** update prices on minute intervals
* **Apps** show "pending" states for seconds

With 10ms blocks and instant execution, this infrastructure becomes the bottleneck. Users won't feel real-time performance if the tools can't keep up.

***

### Realtime API

MegaETH's extension to Ethereum JSON-RPC optimized for sub-10ms latency.

**Core Innovation**: Query against mini-blocks, not EVM blocks

* Transactions reflected within 10ms of arrival
* State changes visible immediately
* Full preconfirmation guarantees maintained

**Enhanced Methods**:

* **State queries** (`eth_getBalance`, `eth_call`, etc.):
  * Return results up to most recent mini-block
  * Use `pending` or `latest` tag for real-time data
  * 100x faster state visibility vs waiting for EVM blocks
* **Transaction queries** (`eth_getTransactionReceipt`):
  * See transactions as soon as mini-block includes them
  * No more waiting for next EVM block
  * Receipt available in \~10ms
* **WebSocket subscriptions** (`eth_subscribe`):
  * **Logs**: Stream as transactions execute
  * **State changes**: Monitor account updates in real-time
  * **Fragments**: Subscribe to mini-block stream

**Example timeline**:

* 0ms: Transaction sent
* 10ms: Included in mini-block, visible in Realtime API
* 1000ms: Included in EVM block (traditional visibility)

**Full specification**: <https://docs.megaeth.com/realtime-api>

***

### realtime\_sendRawTransaction

Revolutionary RPC method that bundles send + receipt in one call.

**Problem it solves**:

* Traditional flow: Send tx → Poll for receipt → Multiple round trips
* Polling wastes time between checks
* Too frequent polling overloads infrastructure
* Like checking mailbox every 10 minutes vs getting notification

**How it works**:

* Send transaction to sequencer
* Sequencer executes immediately (<10ms)
* Returns receipt in same response
* One RPC call for entire flow

**Benefits**:

* **Zero polling overhead**
* **Minimal latency** (network + 10ms execution)
* **Simple integration** (drop-in replacement)
* **Better DevEx** (no subscription management)

**Implementation**:

```json
// Traditional (multiple calls)
1. eth_sendRawTransaction → returns hash
2. eth_getTransactionReceipt (poll) → null
3. eth_getTransactionReceipt (poll) → null
4. eth_getTransactionReceipt (poll) → receipt
// MegaETH (single call)
1. realtime_sendRawTransaction → returns receipt
```

**Technical breakdown**: <https://x.com/yangl1996/status/1913241582700015914>

***

### Paginated Reads

Robust API for processing massive chain data efficiently.

**The data scale problem**:

* MegaETH testnet: 1000 TPS sustained
* Generates 1 year of Ethereum data every 5 days
* Traditional RPCs timeout on large queries
* Apps forced to break queries into tiny chunks

**Pagination solution**:

* **Partial results**: Return what's processed before limits hit
* **Resume pointers**: Continue exactly where query stopped
* **No wasted work**: Every computation counts
* **Optimal round trips**: Minimize network overhead

**Example use case**: Query 1M blocks of logs:

* **Without pagination**:
  * Query fails at 300k blocks
  * Retry with smaller range
  * Start from scratch each time
  * Unreliable, slow, complex
* **With pagination**:
  * First call returns 300k blocks + pointer
  * Second call continues from block 300,001
  * Zero wasted computation
  * Predictable, fast, simple

**Benefits for builders**:

* **Indexers**: Efficient backfilling after downtime
* **Analytics**: Process entire chain history
* **Dashboards**: Load large datasets reliably
* **Infrastructure**: Handle data at scale

**Details**: <https://x.com/yangl1996/status/1924812272679129421>

***

#### Real-Time Oracles

Traditional oracles update prices on minute intervals. MegaETH needs something radically faster.

**RedStone Integration:**

MegaETH partnered with RedStone to build the **fastest push oracle to date**, updating onchain every **2.4ms**.

* **416 oracle updates per second** - in an industry where most chains run at double-digit TPS
* Price data refreshed 250x faster than traditional oracle models
* Enables new categories of DeFi applications requiring instant price feeds
* Real-time capital markets, high-frequency trading strategies, and instant liquidations become viable

This is infrastructure innovation matching chain performance - where oracles keep pace with 10ms blocks instead of becoming the bottleneck.

[Announcement](https://x.com/megaeth/status/1909614320755130514)

***

### Infrastructure Roadmap

**Current (Testnet)**:

* ✅ Realtime API with mini-block queries
* ✅ realtime\_sendRawTransaction
* ✅ Paginated reads for logs
* ✅ WebSocket subscriptions
* ✅ Sub-millisecond oracles

**Coming Soon**:

* Extended pagination (traces, state)
* Batch transaction submission
* Priority transaction lanes
* Historical state queries at mini-block level

**Future Vision**:

* Streaming indexers
* Real-time analytics
* Instant cross-chain messaging

The infrastructure revolution is just beginning. As MegaETH pushes blockchain performance to new limits, expect innovative tools and services that reimagine what's possible in Web3.

---

# Infrastructure

MegaETH solved the slow-chain problem. Next is the slow-infra problem. Oracles, indexers, apps—real-time chains demand innovation on traditional tools before users can *feel* real-time.

### The Infrastructure Challenge

Traditional blockchain infrastructure assumes multi-second block times:

* **RPCs** poll for receipts every few seconds
* **Indexers** batch process blocks periodically
* **Oracles** update prices on minute intervals
* **Apps** show "pending" states for seconds

With 10ms blocks and instant execution, this infrastructure becomes the bottleneck. Users won't feel real-time performance if the tools can't keep up.

***

### Realtime API

MegaETH's extension to Ethereum JSON-RPC optimized for sub-10ms latency.

**Core Innovation**: Query against mini-blocks, not EVM blocks

* Transactions reflected within 10ms of arrival
* State changes visible immediately
* Full preconfirmation guarantees maintained

**Enhanced Methods**:

* **State queries** (`eth_getBalance`, `eth_call`, etc.):
  * Return results up to most recent mini-block
  * Use `pending` or `latest` tag for real-time data
  * 100x faster state visibility vs waiting for EVM blocks
* **Transaction queries** (`eth_getTransactionReceipt`):
  * See transactions as soon as mini-block includes them
  * No more waiting for next EVM block
  * Receipt available in \~10ms
* **WebSocket subscriptions** (`eth_subscribe`):
  * **Logs**: Stream as transactions execute
  * **State changes**: Monitor account updates in real-time
  * **Fragments**: Subscribe to mini-block stream

**Example timeline**:

* 0ms: Transaction sent
* 10ms: Included in mini-block, visible in Realtime API
* 1000ms: Included in EVM block (traditional visibility)

**Full specification**: <https://docs.megaeth.com/realtime-api>

***

### realtime\_sendRawTransaction

Revolutionary RPC method that bundles send + receipt in one call.

**Problem it solves**:

* Traditional flow: Send tx → Poll for receipt → Multiple round trips
* Polling wastes time between checks
* Too frequent polling overloads infrastructure
* Like checking mailbox every 10 minutes vs getting notification

**How it works**:

* Send transaction to sequencer
* Sequencer executes immediately (<10ms)
* Returns receipt in same response
* One RPC call for entire flow

**Benefits**:

* **Zero polling overhead**
* **Minimal latency** (network + 10ms execution)
* **Simple integration** (drop-in replacement)
* **Better DevEx** (no subscription management)

**Implementation**:

```json
// Traditional (multiple calls)
1. eth_sendRawTransaction → returns hash
2. eth_getTransactionReceipt (poll) → null
3. eth_getTransactionReceipt (poll) → null
4. eth_getTransactionReceipt (poll) → receipt
// MegaETH (single call)
1. realtime_sendRawTransaction → returns receipt
```

**Technical breakdown**: <https://x.com/yangl1996/status/1913241582700015914>

***

### Paginated Reads

Robust API for processing massive chain data efficiently.

**The data scale problem**:

* MegaETH testnet: 1000 TPS sustained
* Generates 1 year of Ethereum data every 5 days
* Traditional RPCs timeout on large queries
* Apps forced to break queries into tiny chunks

**Pagination solution**:

* **Partial results**: Return what's processed before limits hit
* **Resume pointers**: Continue exactly where query stopped
* **No wasted work**: Every computation counts
* **Optimal round trips**: Minimize network overhead

**Example use case**: Query 1M blocks of logs:

* **Without pagination**:
  * Query fails at 300k blocks
  * Retry with smaller range
  * Start from scratch each time
  * Unreliable, slow, complex
* **With pagination**:
  * First call returns 300k blocks + pointer
  * Second call continues from block 300,001
  * Zero wasted computation
  * Predictable, fast, simple

**Benefits for builders**:

* **Indexers**: Efficient backfilling after downtime
* **Analytics**: Process entire chain history
* **Dashboards**: Load large datasets reliably
* **Infrastructure**: Handle data at scale

**Details**: <https://x.com/yangl1996/status/1924812272679129421>

***

#### Real-Time Oracles

Traditional oracles update prices on minute intervals. MegaETH needs something radically faster.

**RedStone Integration:**

MegaETH partnered with RedStone to build the **fastest push oracle to date**, updating onchain every **2.4ms**.

* **416 oracle updates per second** - in an industry where most chains run at double-digit TPS
* Price data refreshed 250x faster than traditional oracle models
* Enables new categories of DeFi applications requiring instant price feeds
* Real-time capital markets, high-frequency trading strategies, and instant liquidations become viable

This is infrastructure innovation matching chain performance - where oracles keep pace with 10ms blocks instead of becoming the bottleneck.

[Announcement](https://x.com/megaeth/status/1909614320755130514)

***

### Infrastructure Roadmap

**Current (Testnet)**:

* ✅ Realtime API with mini-block queries
* ✅ realtime\_sendRawTransaction
* ✅ Paginated reads for logs
* ✅ WebSocket subscriptions
* ✅ Sub-millisecond oracles

**Coming Soon**:

* Extended pagination (traces, state)
* Batch transaction submission
* Priority transaction lanes
* Historical state queries at mini-block level

**Future Vision**:

* Streaming indexers
* Real-time analytics
* Instant cross-chain messaging

The infrastructure revolution is just beginning. As MegaETH pushes blockchain performance to new limits, expect innovative tools and services that reimagine what's possible in Web3.

---

# Programs

This page outlines programs and resources for developers building on MegaETH.\
**MegaForge** is where builders first engage with MegaETH technology and prove they're serious about building. **MegaMafia** is the accelerator track within MegaForge - where promising projects get surrounded with intensive resources, mentorship, and pressure.

***

#### **1. MegaForge: Key Program Details**

* **Focus**:
  * **Zero-to-One Dapps** - groundbreaking, never-before-built ideas
  * **Fully On-Chain Dapps** - leveraging MegaETH's 100k TPS for entirely on-chain solutions
  * **Long-Term Dapps** - sustainable projects with lasting impact
* **Benefits**:
  * **Real technical support** - not just docs, but direct access to core engineering team in dedicated Telegram group
  * **Strategic marketing guidance** - positioning, user acquisition, and go-to-market strategy beyond basic promotion
  * **Builder-to-builder collaboration** - projects leverage each other's infrastructure, DeFi primitives, and share tips on real-time APIs
  * **Early access** to latest MegaETH developments and updates
  * **Visibility** - showcase your work and influence the ecosystem
* **How to Apply**:
  * **Submit Your Application:** [Apply here](https://docs.google.com/forms/d/e/1FAIpQLScmaKBIOBlz5ezd1qs2H5Ff5JnWQKUek8BJxMdBB5MoP-FZjw/viewform).
  * Explain how your project aligns with MegaETH's capabilities
  * Once accepted, collaborate with MegaETH experts and the community to launch

***

#### **2. MegaMafia: The Premier Accelerator Program**.

MegaETH's flagship accelerator bringing exceptional builders together to create **zero-to-one applications** only possible with 100k TPS and sub-millisecond block times. Teams co-work and co-live with the core team at intensive builder residencies worldwide.

**Program Evolution**

* **MegaMafia 1.0** - Proven foundation that supercharged existing primitives by leveraging MegaETH's increased bandwidth, reduced latency, and larger contract sizes
  * **$40M+ raised** by participating teams, surpassing MegaETH's own funding
  * Notable projects: Noise, GTE, CapMoney, Euphoria - ecosystem leaders backed by Franklin Templeton, Robot Ventures, Maven 11, Figment Capital
  * OG Mafia pioneers shaped the early vision and demonstrated that focused application development drives real ecosystem value
* **MegaMafia 2.0** - Launched [April 24th](https://x.com/0xMegaMafia/status/1915073541705179305) with broader scope and deeper creativity
  * Challenge builders to imagine **product spaces outside conventional thinking**
  * Focus on apps that **formalize existing loops instead of manufacturing new demand**
  * Take fragmented day-to-day behaviors and distill them into coherent flows that unlock new connections
* **Philosophy**
  * Inspired by **A24's creative approach** - curated by taste and authenticity, not categories
  * Applications over infrastructure - the space is oversaturated with infra while few focus on what truly matters
  * You know it's Mafia-built because you *feel it*
* **Builder Residencies**
  * **Month-long immersive experiences** from Berlin to Copenhagen to Chiang Mai
  * High-bandwidth environments where ideas grow faster and conviction compounds
  * Work, debug, and debate together - these offsites are the program's lifeblood
* **Who Builds Here**
  * Former FANG/Web2 builders, **DeFi 2020 veterans**, **HFT traders**, fresh graduates, and **2015 OGs**
  * All building apps **only possible on MegaETH** - next-gen DeFi, Autonomous Worlds, consumer apps with emotional value
  * **Mafia helps Mafia** - real collaboration and camaraderie with direct access to core team and alumni

**Backing** - **$75M+** from Paradigm, Dragonfly, Franklin Templeton, Maven11, Robot Ventures, and leading crypto visionaries

***

#### **3. Build Independently on MegaETH**

* **Access Developer Resources**: Use tools, documentation, and APIs to start building.
* **Leverage the Ecosystem**: Take advantage of MegaETH's high TPS and sub-millisecond block times.
* **Join the Community & Explore**: Dive into the ecosystem to discover tools, projects, and resources available.\
  Start building today—MegaETH is ready for you!

***

#### **Resources**

* **MegaMafia** ([Website](https://www.megaeth.com/builder) | [@0xMegaMafia](https://x.com/0xMegaMafia))
  * 2.0: Closed with 300+ team submissions ([Announcement](https://x.com/megaeth_labs/status/1930246537558536411))
* **MegaForge** ([Announcement](https://x.com/megaeth_labs/status/1882829039603470371) | [Explanation](https://x.com/hotpot_dao/status/1960145840468844613))
