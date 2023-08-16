// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20("MockUSDT", "mUSDT") {
    constructor() {
        _mint(msg.sender, 10000000 * 10**6); // Sets a supply of 1,000,000 intially
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}