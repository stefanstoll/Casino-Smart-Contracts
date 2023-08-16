// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// The IOwnable contract is an abstraction layer that inherits from the Ownable contract provided by OpenZeppelin.
// It serves as a common base contract for other contracts within the project to utilize ownership functionalities.
// This contract deliberately contains no additional logic or state.
abstract contract IOwnable is Ownable {
    // Intentionally left blank. Just inheriting all features from OpenZeppelin's Ownable contract.
}
