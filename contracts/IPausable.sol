// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";

// The IPausable contract is an abstraction layer that inherits from the Pausable contract provided by OpenZeppelin.
// It serves as a common base contract for other contracts within the project to utilize pausing functionalities.
// This contract deliberately contains no additional logic or state, as it solely exists to extend the features of the Pausable contract.
abstract contract IPausable is Pausable {
    // Intentionally left blank. Just inheriting all features from OpenZeppelin's Pausable contract.
}
