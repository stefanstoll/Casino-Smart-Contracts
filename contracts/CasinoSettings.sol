// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "CasinoSettings" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev This contract provides logic to modify the current casino settings
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

contract CasinoSettings is IOwnable {
    uint16 public houseEdge; // House edge of the casino (% value)
    uint16 public maxBetPercentage; // Maximum bet amount (% of casino LP funds)
    uint256 public maxBytesLength; // Max allowed bytes length for bet parameters, used to control input size and prevent abuse.
    address public transpareWallet; // Wallet managed by Transpare

    event HouseEdgeUpdated(uint256 newHouseEdge);
    event MaxBetPercentageUpdated(uint256 newMaxBetPercentage);
    event TranspareWalletUpdated(address newTranspareWallet);

    constructor() {
        maxBetPercentage = 900;
        houseEdge = 25;
        maxBytesLength = 100;
        transpareWallet = 0x1c39bfb5F5646773C9F05197C3ddF8F9Ab96abE7;
    }

    /**
     * @notice Updates the house edge.
     * @param _newHouseEdge New house edge to set (ex. 25 => 2.5%).
     */
    function updateHouseEdge(uint16 _newHouseEdge) external onlyOwner {
        require(_newHouseEdge >= 0 && _newHouseEdge <= 1000, "House edge not 0 <= x <= 1000");

        houseEdge = _newHouseEdge;

        emit HouseEdgeUpdated(_newHouseEdge);
    }

    /**
     * @notice Updates the max bet percentage.
     * @param _newMaxBetPercentage New max bet percentage to set.
     */
    function updateMaxBet(uint16 _newMaxBetPercentage) external onlyOwner {
        require(_newMaxBetPercentage >= 0 && _newMaxBetPercentage <= 1000, "Max bet not 0 <= x <= 1000");

        maxBetPercentage = _newMaxBetPercentage;

        emit MaxBetPercentageUpdated(_newMaxBetPercentage);
    }

    /**
     * @notice Updates the maximum allowed bytes length for bet parameters.
     * @dev Allows the owner to set a new maximum length for the bet parameters. This ensures control
     *      over the input size and helps prevent abuse by limiting the acceptable input length.
     * @param _maxBytesLength The new maximum length for bet parameters.
     */
    function updateMaxBytesLength(uint256 _maxBytesLength) external onlyOwner {
        maxBytesLength = _maxBytesLength;
    }

    /**
     * @notice Updates the Transpare wallet
     * @param _newTranspareWallet New Transpare wallet to set.
     */
    function updateTranspareWallet(address _newTranspareWallet) external onlyOwner {
        require(_newTranspareWallet != address(0), "Not a real address");

        transpareWallet = _newTranspareWallet;

        emit TranspareWalletUpdated(_newTranspareWallet);
    }
}
