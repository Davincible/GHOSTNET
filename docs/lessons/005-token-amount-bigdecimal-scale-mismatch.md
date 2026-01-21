# Lesson: TokenAmount BigDecimal Scale Mismatch

**Date:** 2026-01-21  
**Category:** Database/Rust/Type Conversion  
**Difficulty:** ~2 hours

## Problem

Position amounts were being incorrectly stored and retrieved from PostgreSQL. When storing 1.5 DATA tokens, the database would return 2 DATA.

Debug output showed:
```
position after update: amount = 1.5
position read back:    amount = 2.0
```

## What Didn't Work

1. **Checked handler logic** - The handler correctly set `position.amount = new_total` where `new_total` was correctly decoded from the event.

2. **Checked SQL upsert** - The `ON CONFLICT (id) DO UPDATE SET amount = EXCLUDED.amount` was correct.

3. **Checked event decoding** - The Alloy decode showed correct values: `StakeAdded { amount: 500000000000000000, newTotal: 1500000000000000000 }`.

## Solution

The issue was a **scale mismatch** between `TokenAmount` and the database schema.

### Root Cause

1. `TokenAmount` stores values in **human-readable units** (e.g., "1.5" for 1.5 DATA tokens)
2. The schema uses `NUMERIC(78, 0)` - **zero decimal places** (integers only)
3. `to_bigdecimal()` was returning the human-readable value ("1.5")
4. PostgreSQL rounded "1.5" to "2" when storing in `NUMERIC(78, 0)`

### Fix

Changed `to_bigdecimal()` and `from_bigdecimal()` to convert between human units and wei:

```rust
// Before (broken):
pub fn to_bigdecimal(&self) -> sqlx::types::BigDecimal {
    self.0.to_string().parse().unwrap_or_default()  // Returns "1.5"
}

// After (fixed):
pub fn to_bigdecimal(&self) -> sqlx::types::BigDecimal {
    // Scale by 10^18 to convert human units to wei
    let wei = &self.0 * BigDecimal::from(10_u64.pow(18));
    let wei_str = wei.to_string().split('.').next().unwrap_or("0").to_string();
    wei_str.parse().unwrap_or_default()  // Returns "1500000000000000000"
}

pub fn from_bigdecimal(value: &sqlx::types::BigDecimal) -> Self {
    // Value from DB is in wei, divide by 10^18 to get human units
    let value_str = value.to_string();
    let wei = BigDecimal::from_str(&value_str).unwrap_or_default();
    let human = wei / BigDecimal::from(10_u64.pow(18));
    Self(human)
}
```

## Why It Works

The schema comment says "Current staked amount (wei)" - the database expects wei values (integers). By scaling up to wei when storing and scaling down when reading, we maintain precision and match the schema's expectations.

The flow is now:
1. Event: `U256(1500000000000000000)` wei
2. `from_wei()`: TokenAmount("1.5") human units
3. `to_bigdecimal()`: BigDecimal("1500000000000000000") wei
4. DB stores: `1500000000000000000` (no precision loss)
5. `from_bigdecimal()`: TokenAmount("1.5") human units
6. `to_wei(18)`: `U256(1500000000000000000)` wei

## Prevention

1. **Verify schema and code alignment** - If schema says "wei", code should store wei
2. **Test with non-integer amounts** - The original tests only used amounts like "1 DATA" or "2 DATA" which are integers when represented as human units. Testing with "1.5 DATA" exposed the bug.
3. **Consider using wei internally** - Storing human-readable units internally is convenient but creates conversion points where precision can be lost
4. **Add assertions in serialization** - When storing to DB, assert that the value is an integer when schema expects integer

## Related

- Schema file: `migrations/20260121100001_schema_v2_optimized.sql`
- TokenAmount impl: `src/types/primitives.rs`
