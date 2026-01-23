// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        // Mint 1 billion tokens to deployer
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }

    /// @notice Anyone can mint for testing
    function mint(
        address to,
        uint256 amount
    ) external {
        _mint(to, amount);
    }
}
