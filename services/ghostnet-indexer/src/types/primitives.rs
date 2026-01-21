//! Validated primitive types for domain entities.
//!
//! These newtypes provide:
//! - Type safety (can't accidentally pass amount as address)
//! - Validation at construction time
//! - Domain semantics in function signatures

use std::fmt;
use std::str::FromStr;

use alloy::primitives::{Address, U256};
use bigdecimal::BigDecimal;
use serde::{Deserialize, Serialize};
use thiserror::Error;

// ═══════════════════════════════════════════════════════════════════════════════
// ETHEREUM ADDRESS
// ═══════════════════════════════════════════════════════════════════════════════

/// Validated 20-byte Ethereum address.
///
/// This newtype ensures addresses are always exactly 20 bytes.
/// Use `Address` from `alloy-primitives` for on-chain interaction,
/// but this type for persistence and domain logic.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct EthAddress([u8; 20]);

impl EthAddress {
    /// Create from a fixed-size array (infallible).
    #[must_use]
    pub const fn new(bytes: [u8; 20]) -> Self {
        Self(bytes)
    }

    /// Try to create from a byte slice.
    ///
    /// # Errors
    /// Returns `InvalidAddress::WrongLength` if the slice is not exactly 20 bytes.
    pub fn from_slice(slice: &[u8]) -> Result<Self, InvalidAddress> {
        let bytes: [u8; 20] = slice
            .try_into()
            .map_err(|_| InvalidAddress::WrongLength(slice.len()))?;
        Ok(Self(bytes))
    }

    /// Parse from hex string (with or without 0x prefix).
    ///
    /// # Errors
    /// Returns `InvalidAddress` if the string is not valid hex or wrong length.
    pub fn from_hex(s: &str) -> Result<Self, InvalidAddress> {
        let s = s.strip_prefix("0x").unwrap_or(s);
        if s.len() != 40 {
            return Err(InvalidAddress::WrongLength(s.len() / 2));
        }
        let bytes = hex::decode(s).map_err(|_| InvalidAddress::InvalidHex)?;
        Self::from_slice(&bytes)
    }

    /// Get the underlying bytes.
    #[must_use]
    pub const fn as_bytes(&self) -> &[u8; 20] {
        &self.0
    }

    /// Get as a byte slice.
    #[must_use]
    pub const fn as_slice(&self) -> &[u8] {
        &self.0
    }

    /// Convert to lowercase hex string with 0x prefix.
    #[must_use]
    pub fn to_hex(&self) -> String {
        format!("0x{}", hex::encode(self.0))
    }

    /// Check if this is the zero address.
    #[must_use]
    pub fn is_zero(&self) -> bool {
        self.0 == [0u8; 20]
    }

    /// The zero address (0x0000...0000).
    pub const ZERO: Self = Self([0u8; 20]);
}

impl fmt::Debug for EthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "EthAddress({})", self.to_hex())
    }
}

impl fmt::Display for EthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_hex())
    }
}

impl From<EthAddress> for String {
    fn from(addr: EthAddress) -> Self {
        addr.to_hex()
    }
}

impl TryFrom<String> for EthAddress {
    type Error = InvalidAddress;

    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::from_hex(&s)
    }
}

impl TryFrom<&str> for EthAddress {
    type Error = InvalidAddress;

    fn try_from(s: &str) -> Result<Self, Self::Error> {
        Self::from_hex(s)
    }
}

impl From<[u8; 20]> for EthAddress {
    fn from(bytes: [u8; 20]) -> Self {
        Self::new(bytes)
    }
}

impl From<Address> for EthAddress {
    fn from(addr: Address) -> Self {
        Self::new(addr.0.0)
    }
}

impl From<EthAddress> for Address {
    fn from(addr: EthAddress) -> Self {
        Self::from(addr.0)
    }
}

/// Error for invalid Ethereum addresses.
#[derive(Debug, Clone, Error)]
pub enum InvalidAddress {
    /// Address has wrong byte length.
    #[error("wrong length: expected 20 bytes, got {0}")]
    WrongLength(usize),
    /// Address contains invalid hex characters.
    #[error("invalid hex encoding")]
    InvalidHex,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN AMOUNT
// ═══════════════════════════════════════════════════════════════════════════════

/// Non-negative token amount with arbitrary precision.
///
/// Backed by `BigDecimal` for exact arithmetic. Amounts are always non-negative.
/// Use this type for database persistence and domain logic. For on-chain
/// interaction, convert to/from `U256`.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct TokenAmount(BigDecimal);

impl TokenAmount {
    /// Zero amount.
    #[must_use]
    pub fn zero() -> Self {
        Self(BigDecimal::from(0))
    }

    /// Create from `BigDecimal`, validating non-negative.
    ///
    /// # Errors
    /// Returns `InvalidAmount::Negative` if value is negative.
    pub fn new(value: BigDecimal) -> Result<Self, InvalidAmount> {
        if value.sign() == bigdecimal::num_bigint::Sign::Minus {
            return Err(InvalidAmount::Negative);
        }
        Ok(Self(value))
    }

    /// Parse from string representation.
    ///
    /// # Errors
    /// Returns `InvalidAmount` if parsing fails or value is negative.
    pub fn parse(s: &str) -> Result<Self, InvalidAmount> {
        let value = BigDecimal::from_str(s).map_err(|_| InvalidAmount::ParseError)?;
        Self::new(value)
    }

    /// Create from `U256` (wei) with decimals.
    ///
    /// Converts a raw token amount (e.g., wei for 18 decimal tokens)
    /// to a human-readable decimal value.
    #[must_use]
    pub fn from_wei(wei: U256, decimals: u8) -> Self {
        let wei_str = wei.to_string();
        // U256::to_string is always valid decimal
        let value = BigDecimal::from_str(&wei_str).unwrap_or_default()
            / BigDecimal::from(10_u64.pow(u32::from(decimals)));
        Self(value)
    }

    /// Get the underlying `BigDecimal`.
    #[must_use]
    pub const fn as_decimal(&self) -> &BigDecimal {
        &self.0
    }

    /// Convert to wei (`U256`) given decimals.
    ///
    /// Converts a human-readable amount to raw token units.
    #[must_use]
    pub fn to_wei(&self, decimals: u8) -> U256 {
        let scaled = &self.0 * BigDecimal::from(10_u64.pow(u32::from(decimals)));
        let int_str = scaled
            .to_string()
            .split('.')
            .next()
            .unwrap_or("0")
            .to_string();
        U256::from_str(&int_str).unwrap_or_default()
    }

    /// Check if zero.
    #[must_use]
    pub fn is_zero(&self) -> bool {
        self.0.sign() == bigdecimal::num_bigint::Sign::NoSign
    }

    /// Saturating addition.
    #[must_use]
    pub fn saturating_add(&self, other: &Self) -> Self {
        Self(&self.0 + &other.0)
    }

    /// Saturating subtraction (floors at zero).
    #[must_use]
    pub fn saturating_sub(&self, other: &Self) -> Self {
        let result = &self.0 - &other.0;
        if result.sign() == bigdecimal::num_bigint::Sign::Minus {
            Self::zero()
        } else {
            Self(result)
        }
    }

    /// Convert to `sqlx::types::BigDecimal` for database storage.
    #[must_use]
    pub fn to_bigdecimal(&self) -> sqlx::types::BigDecimal {
        // SQLx BigDecimal and bigdecimal::BigDecimal are compatible
        // via string conversion (they may be different versions)
        self.0.to_string().parse().unwrap_or_default()
    }

    /// Create from `sqlx::types::BigDecimal`.
    #[must_use]
    pub fn from_bigdecimal(value: &sqlx::types::BigDecimal) -> Self {
        // Parse via string to handle version compatibility
        let s = value.to_string();
        Self::parse(&s).unwrap_or_else(|_| Self::zero())
    }
}

impl fmt::Debug for TokenAmount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "TokenAmount({})", self.0)
    }
}

impl fmt::Display for TokenAmount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl From<TokenAmount> for String {
    fn from(amount: TokenAmount) -> Self {
        amount.0.to_string()
    }
}

impl TryFrom<String> for TokenAmount {
    type Error = InvalidAmount;

    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::parse(&s)
    }
}

impl Default for TokenAmount {
    fn default() -> Self {
        Self::zero()
    }
}

impl PartialOrd for TokenAmount {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for TokenAmount {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.cmp(&other.0)
    }
}

/// Error for invalid token amounts.
#[derive(Debug, Clone, Error)]
pub enum InvalidAmount {
    /// Amount cannot be negative.
    #[error("amount cannot be negative")]
    Negative,
    /// Failed to parse amount string.
    #[error("failed to parse amount")]
    ParseError,
}

// ═══════════════════════════════════════════════════════════════════════════════
// GHOST STREAK (bounded counter)
// ═══════════════════════════════════════════════════════════════════════════════

/// Ghost streak counter (non-negative, bounded).
///
/// Tracks consecutive scan survivals. Max value is `i32::MAX` for DB compatibility.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct GhostStreak(i32);

impl GhostStreak {
    /// Zero streak.
    pub const ZERO: Self = Self(0);

    /// Maximum possible streak (for DB i32 compatibility).
    pub const MAX: Self = Self(i32::MAX);

    /// Create a new streak value.
    ///
    /// # Errors
    /// Returns `InvalidStreak::Negative` if value is negative.
    pub const fn new(value: i32) -> Result<Self, InvalidStreak> {
        if value < 0 {
            return Err(InvalidStreak::Negative);
        }
        Ok(Self(value))
    }

    /// Create a new streak value without validation.
    ///
    /// # Safety
    /// The caller must ensure the value is non-negative.
    #[must_use]
    pub const fn new_unchecked(value: i32) -> Self {
        Self(value)
    }

    /// Get the value.
    #[must_use]
    pub const fn get(&self) -> i32 {
        self.0
    }

    /// Alias for `get()` for consistency with other newtypes.
    #[must_use]
    pub const fn value(&self) -> i32 {
        self.0
    }

    /// Increment by one (saturating at MAX).
    #[must_use]
    pub const fn increment(&self) -> Self {
        Self(self.0.saturating_add(1))
    }

    /// Reset to zero.
    #[must_use]
    pub const fn reset(&self) -> Self {
        Self::ZERO
    }
}

impl Default for GhostStreak {
    fn default() -> Self {
        Self::ZERO
    }
}

impl From<GhostStreak> for i32 {
    fn from(streak: GhostStreak) -> Self {
        streak.0
    }
}

impl TryFrom<i32> for GhostStreak {
    type Error = InvalidStreak;

    fn try_from(value: i32) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}

impl fmt::Display for GhostStreak {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Error for invalid ghost streak values.
#[derive(Debug, Clone, Copy, Error)]
pub enum InvalidStreak {
    /// Streak cannot be negative.
    #[error("streak cannot be negative")]
    Negative,
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK NUMBER (for type clarity)
// ═══════════════════════════════════════════════════════════════════════════════

/// Block number newtype for clarity in function signatures.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct BlockNumber(u64);

impl BlockNumber {
    /// Create a new block number.
    #[must_use]
    pub const fn new(n: u64) -> Self {
        Self(n)
    }

    /// Get the value.
    #[must_use]
    pub const fn get(&self) -> u64 {
        self.0
    }

    /// Alias for `get()` for consistency with other newtypes.
    #[must_use]
    pub const fn value(&self) -> u64 {
        self.0
    }

    /// Returns the next block number (saturating at `u64::MAX`).
    #[must_use]
    pub const fn next(&self) -> Self {
        Self(self.0.saturating_add(1))
    }

    /// Returns the previous block number (saturating at 0).
    #[must_use]
    pub const fn prev(&self) -> Self {
        Self(self.0.saturating_sub(1))
    }
}

impl From<u64> for BlockNumber {
    fn from(n: u64) -> Self {
        Self(n)
    }
}

impl From<BlockNumber> for u64 {
    fn from(b: BlockNumber) -> Self {
        b.0
    }
}

impl From<BlockNumber> for i64 {
    #[allow(clippy::cast_possible_wrap)]
    fn from(b: BlockNumber) -> Self {
        b.0 as Self
    }
}

impl fmt::Display for BlockNumber {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    mod eth_address_tests {
        use super::*;

        #[test]
        fn from_hex_with_prefix() {
            let addr = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
            assert_eq!(addr.to_hex(), "0x1234567890123456789012345678901234567890");
        }

        #[test]
        fn from_hex_without_prefix() {
            let addr = EthAddress::from_hex("1234567890123456789012345678901234567890").unwrap();
            assert_eq!(addr.to_hex(), "0x1234567890123456789012345678901234567890");
        }

        #[test]
        fn from_hex_wrong_length() {
            assert!(EthAddress::from_hex("0x1234").is_err());
        }

        #[test]
        fn from_hex_invalid_chars() {
            assert!(EthAddress::from_hex("0xgggggggggggggggggggggggggggggggggggggggg").is_err());
        }

        #[test]
        fn zero_address() {
            assert!(EthAddress::ZERO.is_zero());
            assert_eq!(
                EthAddress::ZERO.to_hex(),
                "0x0000000000000000000000000000000000000000"
            );
        }

        #[test]
        fn alloy_address_roundtrip() {
            let addr_hex = "0x1234567890123456789012345678901234567890";
            let eth_addr = EthAddress::from_hex(addr_hex).unwrap();
            let alloy_addr: Address = eth_addr.into();
            let back: EthAddress = alloy_addr.into();
            assert_eq!(eth_addr, back);
        }
    }

    mod token_amount_tests {
        use super::*;

        #[test]
        fn zero_is_zero() {
            assert!(TokenAmount::zero().is_zero());
        }

        #[test]
        fn parse_integer() {
            let amount = TokenAmount::parse("1000").unwrap();
            assert_eq!(amount.to_string(), "1000");
        }

        #[test]
        fn parse_decimal() {
            let amount = TokenAmount::parse("123.456").unwrap();
            assert_eq!(amount.to_string(), "123.456");
        }

        #[test]
        fn parse_negative_fails() {
            assert!(TokenAmount::parse("-100").is_err());
        }

        #[test]
        fn from_wei_18_decimals() {
            // 1 token = 10^18 wei
            let wei = U256::from(1_000_000_000_000_000_000_u128);
            let amount = TokenAmount::from_wei(wei, 18);
            assert_eq!(amount.to_string(), "1");
        }

        #[test]
        fn to_wei_18_decimals() {
            let amount = TokenAmount::parse("1.5").unwrap();
            let wei = amount.to_wei(18);
            assert_eq!(wei, U256::from(1_500_000_000_000_000_000_u128));
        }

        #[test]
        fn saturating_add() {
            let a = TokenAmount::parse("100").unwrap();
            let b = TokenAmount::parse("50").unwrap();
            let result = a.saturating_add(&b);
            assert_eq!(result.to_string(), "150");
        }

        #[test]
        fn saturating_sub_normal() {
            let a = TokenAmount::parse("100").unwrap();
            let b = TokenAmount::parse("30").unwrap();
            let result = a.saturating_sub(&b);
            assert_eq!(result.to_string(), "70");
        }

        #[test]
        fn saturating_sub_underflow() {
            let a = TokenAmount::parse("30").unwrap();
            let b = TokenAmount::parse("100").unwrap();
            let result = a.saturating_sub(&b);
            assert!(result.is_zero());
        }
    }

    mod ghost_streak_tests {
        use super::*;

        #[test]
        fn zero_is_default() {
            assert_eq!(GhostStreak::default(), GhostStreak::ZERO);
        }

        #[test]
        fn new_valid() {
            let streak = GhostStreak::new(5).unwrap();
            assert_eq!(streak.get(), 5);
        }

        #[test]
        fn new_negative_fails() {
            assert!(GhostStreak::new(-1).is_err());
        }

        #[test]
        fn increment() {
            let streak = GhostStreak::ZERO.increment();
            assert_eq!(streak.get(), 1);
        }

        #[test]
        fn increment_saturates() {
            let streak = GhostStreak::MAX.increment();
            assert_eq!(streak, GhostStreak::MAX);
        }

        #[test]
        fn reset() {
            let streak = GhostStreak::new(10).unwrap().reset();
            assert_eq!(streak, GhostStreak::ZERO);
        }
    }

    mod block_number_tests {
        use super::*;

        #[test]
        fn new_and_get() {
            let block = BlockNumber::new(12345);
            assert_eq!(block.get(), 12345);
        }

        #[test]
        fn next() {
            let block = BlockNumber::new(100);
            assert_eq!(block.next().get(), 101);
        }

        #[test]
        fn prev() {
            let block = BlockNumber::new(100);
            assert_eq!(block.prev().get(), 99);
        }

        #[test]
        fn prev_saturates_at_zero() {
            let block = BlockNumber::new(0);
            assert_eq!(block.prev().get(), 0);
        }

        #[test]
        fn from_u64() {
            let block: BlockNumber = 42_u64.into();
            assert_eq!(block.get(), 42);
        }
    }
}
