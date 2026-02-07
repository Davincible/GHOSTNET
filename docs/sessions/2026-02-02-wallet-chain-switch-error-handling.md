# Session Log: Wallet Chain Switch Error Handling

**Date:** 2026-02-02  
**Type:** Debug  
**Status:** Completed

## Session Overview
Handled a wallet chain switch failure where MetaMask rejects adding MegaETH Testnet
because a legacy chain ID already exists with the same RPC endpoint.

## Key Decisions Made
- Detect the legacy RPC conflict error and surface a targeted message guiding users to
  update the chain ID to 6343 instead of treating it as a generic rejection.
- Skip `switchChain` calls when the wallet is already on the default chain to avoid
  unnecessary add-network prompts.
- Avoid passing `chainId` during initial connect so injected wallets do not attempt
  an automatic add-network flow. Chain switching is handled explicitly after connect.

## Assumptions Made
- The correct MegaETH Testnet chain ID is 6343 and the 6342 entry is a legacy network
  still present in some wallets.

## Open Questions
- None.

## Artifacts Created
- `docs/sessions/2026-02-02-wallet-chain-switch-error-handling.md`

## Next Steps
- None.
