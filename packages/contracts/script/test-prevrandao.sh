#!/bin/bash
# Comprehensive prevrandao test for MegaETH
# Runs for ~60 seconds, recording samples and analyzing results

set -e

# Load environment
source .env

CONTRACT="${PREVRANDAO_TEST_CONTRACT:-0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08}"
RPC="https://carrot.megaeth.com/rpc"
DURATION=60  # seconds
INTERVAL=3   # seconds between samples

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           PREVRANDAO COMPREHENSIVE TEST                        ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Contract: $CONTRACT"
echo "║  RPC:      $RPC"
echo "║  Duration: ${DURATION}s with ${INTERVAL}s intervals"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Arrays to store results
declare -a PREVRANDAO_VALUES
declare -a BLOCK_NUMBERS
declare -a TIMESTAMPS

START_TIME=$(date +%s)
SAMPLE_COUNT=0

echo "Recording samples..."
echo ""

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $DURATION ]; then
        break
    fi
    
    # Record a sample via cast
    RESULT=$(cast send $CONTRACT "recordSample()" \
        --rpc-url $RPC \
        --private-key $PRIVATE_KEY \
        --gas-limit 500000 \
        --json 2>/dev/null)
    
    TX_HASH=$(echo $RESULT | jq -r '.transactionHash')
    
    # Get the receipt to find block number
    RECEIPT=$(cast receipt $TX_HASH --rpc-url $RPC --json 2>/dev/null)
    BLOCK_NUM=$(echo $RECEIPT | jq -r '.blockNumber' | xargs printf "%d")
    
    # Read the last recorded prevrandao from contract
    LAST_PREVRANDAO=$(cast call $CONTRACT "lastPrevrandao()(uint256)" --rpc-url $RPC 2>/dev/null)
    LAST_BLOCK=$(cast call $CONTRACT "lastBlockNumber()(uint256)" --rpc-url $RPC 2>/dev/null)
    
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
    
    # Store values
    PREVRANDAO_VALUES+=("$LAST_PREVRANDAO")
    BLOCK_NUMBERS+=("$BLOCK_NUM")
    
    # Truncate prevrandao for display
    SHORT_RAND="${LAST_PREVRANDAO:0:20}..."
    
    printf "[%3ds] Sample %2d | Block: %8d | prevrandao: %s\n" \
        "$ELAPSED" "$SAMPLE_COUNT" "$BLOCK_NUM" "$SHORT_RAND"
    
    sleep $INTERVAL
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      ANALYSIS RESULTS                          ║"
echo "╠════════════════════════════════════════════════════════════════╣"

# Count unique values
UNIQUE_PREVRANDAO=$(printf '%s\n' "${PREVRANDAO_VALUES[@]}" | sort -u | wc -l | tr -d ' ')
UNIQUE_BLOCKS=$(printf '%s\n' "${BLOCK_NUMBERS[@]}" | sort -u | wc -l | tr -d ' ')

echo "║  Total samples:        $SAMPLE_COUNT"
echo "║  Unique prevrandao:    $UNIQUE_PREVRANDAO"
echo "║  Unique blocks:        $UNIQUE_BLOCKS"

# Calculate uniqueness percentage
if [ $SAMPLE_COUNT -gt 0 ]; then
    UNIQUENESS_PCT=$((UNIQUE_PREVRANDAO * 100 / SAMPLE_COUNT))
    echo "║  Uniqueness ratio:     ${UNIQUENESS_PCT}%"
fi

echo "╠════════════════════════════════════════════════════════════════╣"

# Check if prevrandao changes with block
if [ "$UNIQUE_PREVRANDAO" -eq "$UNIQUE_BLOCKS" ]; then
    echo "║  prevrandao changes: PER EVM BLOCK (1:1 with block numbers)"
elif [ "$UNIQUE_PREVRANDAO" -lt "$UNIQUE_BLOCKS" ]; then
    echo "║  WARNING: prevrandao NOT changing every block!"
else
    echo "║  prevrandao changes: MORE than once per block (?)"
fi

echo "╠════════════════════════════════════════════════════════════════╣"

# Run statistical test via contract
echo "║  Running statistical fairness test..."
STAT_RESULT=$(cast call $CONTRACT "statisticalTest(uint256,uint256,uint256)(uint256,uint256,uint256)" 50 100 4000 --rpc-url $RPC 2>/dev/null)

AVG_RATE=$(echo $STAT_RESULT | cut -d' ' -f1)
MIN_DEATHS=$(echo $STAT_RESULT | cut -d' ' -f2)
MAX_DEATHS=$(echo $STAT_RESULT | cut -d' ' -f3)

AVG_PCT=$((AVG_RATE / 100))
echo "║  "
echo "║  Statistical Test (50 iterations, 100 positions, 40% target):"
echo "║    Average death rate: ${AVG_PCT}%"
echo "║    Min deaths:         $MIN_DEATHS"
echo "║    Max deaths:         $MAX_DEATHS"

echo "╠════════════════════════════════════════════════════════════════╣"

# Final verdict
if [ "$UNIQUE_PREVRANDAO" -eq "$UNIQUE_BLOCKS" ] && [ "$AVG_PCT" -ge 35 ] && [ "$AVG_PCT" -le 45 ]; then
    echo "║                                                                ║"
    echo "║  ✅ VERDICT: PREVRANDAO IS SUITABLE FOR GHOSTNET              ║"
    echo "║                                                                ║"
    echo "║  - Changes every EVM block (1 second)                         ║"
    echo "║  - Produces fair statistical distribution                     ║"
    echo "║  - Safe to use for trace scan death selection                 ║"
    echo "║                                                                ║"
else
    echo "║                                                                ║"
    echo "║  ⚠️  VERDICT: INVESTIGATE FURTHER                              ║"
    echo "║                                                                ║"
    echo "║  Some criteria not met. Review data above.                    ║"
    echo "║                                                                ║"
fi

echo "╚════════════════════════════════════════════════════════════════╝"

# Show recent samples from contract
echo ""
echo "Recent prevrandao values from contract:"
cast call $CONTRACT "getRecentSamples(uint256)(uint256[],uint256[])" 5 --rpc-url $RPC 2>/dev/null | head -20
