# Ghost Fleet Operations Runbook

This runbook covers common operational procedures for the Ghost Fleet service.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Incident Response](#incident-response)
3. [Maintenance Procedures](#maintenance-procedures)
4. [Emergency Procedures](#emergency-procedures)

---

## Daily Operations

### Health Check

Verify service health:

```bash
# Check service is running
curl -s http://localhost:8080/health | jq

# Expected response:
# { "status": "healthy", "uptime_secs": 12345 }

# Check readiness
curl -s http://localhost:8080/health/ready | jq

# Check metrics
curl -s http://localhost:8080/metrics | grep ghost_fleet
```

### Log Review

Review recent logs for errors:

```bash
# Docker
docker logs ghost-fleet --since 1h | grep -i error

# Systemd
journalctl -u ghost-fleet --since "1 hour ago" | grep -i error
```

### Wallet Balance Check

Monitor wallet balances for low funds:

```bash
# Using cast (Foundry)
for addr in $(cat wallets.csv | cut -d',' -f1 | tail -n +2); do
  balance=$(cast balance $addr --rpc-url https://carrot.megaeth.com/rpc)
  echo "$addr: $balance wei"
done
```

---

## Incident Response

### IR-001: Service Not Responding

**Symptoms:**
- Health check fails
- No logs being written
- Actions not executing

**Steps:**

1. Check if process is running:
   ```bash
   # Docker
   docker ps | grep ghost-fleet
   
   # Systemd
   systemctl status ghost-fleet
   ```

2. Check logs for crash reason:
   ```bash
   docker logs ghost-fleet --tail 100
   ```

3. Check system resources:
   ```bash
   free -h
   df -h
   ```

4. Restart service:
   ```bash
   docker restart ghost-fleet
   # or
   systemctl restart ghost-fleet
   ```

5. If restart fails, check config:
   ```bash
   ghost-fleet --config config.toml validate
   ```

### IR-002: High Error Rate

**Symptoms:**
- `ghost_fleet_errors_total` metric increasing rapidly
- Multiple circuit breakers tripped

**Steps:**

1. Check error breakdown in logs:
   ```bash
   docker logs ghost-fleet --since 10m | grep ERROR | sort | uniq -c | sort -rn
   ```

2. Common causes:
   - **RPC errors**: Check RPC endpoint health
   - **Nonce errors**: May need nonce sync
   - **Insufficient gas**: Check wallet balances
   - **Contract errors**: Check contract state

3. If RPC issues:
   ```bash
   # Test RPC
   cast block-number --rpc-url https://carrot.megaeth.com/rpc
   ```

4. If wallet balance issues:
   - Pause service
   - Fund wallets
   - Resume service

### IR-003: Circuit Breaker Tripped

**Symptoms:**
- Specific wallet(s) stop taking actions
- `ghost_fleet_circuit_breaker_trips` metric increased

**Steps:**

1. Identify affected wallets:
   ```bash
   docker logs ghost-fleet | grep "circuit breaker" | tail -20
   ```

2. Investigate cause:
   - Check wallet transaction history
   - Check for revert reasons
   - Verify contract state

3. Reset circuit breaker (after fixing issue):
   ```bash
   curl -X POST http://localhost:8080/admin/reset/wallet-001
   ```

### IR-004: RPC Rate Limited

**Symptoms:**
- 429 errors in logs
- Actions slowing down

**Steps:**

1. Reduce activity:
   ```bash
   # Temporarily increase tick interval in config
   # Or pause service
   curl -X POST http://localhost:8080/admin/pause
   ```

2. Consider:
   - Using multiple RPC endpoints
   - Reducing number of active wallets
   - Contacting RPC provider for limit increase

---

## Maintenance Procedures

### MP-001: Add New Wallets

1. Generate new wallets:
   ```bash
   ./scripts/generate-wallets.sh 10 ./new-wallets degen
   ```

2. Fund the wallets:
   ```bash
   # Transfer ETH for gas
   for addr in $(cat new-wallets/wallets.csv | cut -d',' -f1 | tail -n +2); do
     cast send $addr --value 0.01ether --private-key $FUNDER_KEY --rpc-url $RPC
   done
   ```

3. Update config:
   ```bash
   # Append to config
   cat new-wallets/wallets.toml >> config/production.toml
   ```

4. Restart service:
   ```bash
   docker restart ghost-fleet
   ```

### MP-002: Update Configuration

1. Validate new config:
   ```bash
   ghost-fleet --config new-config.toml validate
   ```

2. Backup current config:
   ```bash
   cp config/production.toml config/production.toml.bak
   ```

3. Apply new config:
   ```bash
   cp new-config.toml config/production.toml
   ```

4. Restart service:
   ```bash
   docker restart ghost-fleet
   ```

5. Verify health:
   ```bash
   curl http://localhost:8080/health
   ```

### MP-003: Upgrade Service

1. Build new version:
   ```bash
   git pull
   cd services
   docker build -t ghost-fleet:new -f ghost-fleet/Dockerfile .
   ```

2. Test locally (optional):
   ```bash
   docker run --rm ghost-fleet:new --help
   ```

3. Stop old service:
   ```bash
   docker stop ghost-fleet
   ```

4. Start new version:
   ```bash
   docker run -d --name ghost-fleet-new \
     -v /path/to/config.toml:/etc/ghost-fleet/config.toml:ro \
     ghost-fleet:new
   ```

5. Verify health:
   ```bash
   curl http://localhost:8080/health
   ```

6. Cleanup:
   ```bash
   docker rm ghost-fleet
   docker rename ghost-fleet-new ghost-fleet
   docker image prune -f
   ```

### MP-004: Rotate Wallets

For operational security, periodically rotate wallets:

1. Generate new wallets
2. Fund new wallets
3. Extract from old wallets (claim rewards, extract stake)
4. Update config with new wallets
5. Restart service
6. Securely delete old wallet keys

---

## Emergency Procedures

### EP-001: Emergency Stop

**When to use:** Security incident, critical bug, unexpected behavior

```bash
# Immediate pause via API
curl -X POST http://localhost:8080/admin/pause

# Or stop the service entirely
docker stop ghost-fleet

# Or kill immediately
docker kill ghost-fleet
```

### EP-002: Extract All Funds

**When to use:** Shutting down, security compromise

1. Pause service
2. For each wallet:
   - Claim pending rewards
   - Extract all stake
   - Transfer remaining ETH/DATA to safe address

```bash
# Example extraction script
for wallet in $(cat wallets.csv | tail -n +2); do
  addr=$(echo $wallet | cut -d',' -f1)
  key=$(echo $wallet | cut -d',' -f2)
  
  # Claim rewards (adjust contract call as needed)
  cast send $GHOST_CORE "claimRewards()" --private-key $key --rpc-url $RPC
  
  # Extract stake (adjust as needed)
  cast send $GHOST_CORE "extract()" --private-key $key --rpc-url $RPC
done
```

### EP-003: Rollback

**When to use:** Bad upgrade, config error

1. Stop current service
2. Restore previous config:
   ```bash
   cp config/production.toml.bak config/production.toml
   ```
3. Start previous version:
   ```bash
   docker run -d --name ghost-fleet ghost-fleet:previous
   ```

---

## Contacts

| Role | Contact |
|------|---------|
| On-call | [Your contact] |
| Escalation | [Manager contact] |
| MegaETH Support | [Support channel] |

## Appendix: Common Commands

```bash
# View logs
docker logs -f ghost-fleet

# Check status
curl http://localhost:8080/health | jq

# Pause all operations
curl -X POST http://localhost:8080/admin/pause

# Resume operations
curl -X POST http://localhost:8080/admin/resume

# Reset specific wallet circuit breaker
curl -X POST http://localhost:8080/admin/reset/wallet-001

# Get detailed status
curl http://localhost:8080/admin/status | jq

# Check metrics
curl http://localhost:8080/metrics
```
