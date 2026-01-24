//! Action decision and execution logic.
//!
//! This module contains the logic for deciding and executing actions
//! on GhostCore and HashCrash contracts.

pub mod ghost_core;
pub mod hashcrash;

pub use ghost_core::GhostCoreDecider;
pub use hashcrash::HashCrashDecider;
