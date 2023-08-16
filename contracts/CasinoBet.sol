// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "CasinoBet" Contract
 * @author Stefan Stoll, Stefan@Transpare.io
 * @dev This contract facilitates casino betting by allowing users to place bets and forwarding them to the game contract.
 */

pragma solidity ^0.8.0;

import "./CasinoGameContracts.sol";

contract CasinoBet is CasinoGameContracts {
    // Stores all active casino bets
    struct ActiveCasinoBet {
        address user;
        address casinoGameContract;
        uint256 betAmount;
        bytes betParameters;
        uint256 betPlacedAt;
    }

    // Nonces to active game data
    mapping(uint256 => ActiveCasinoBet) public activeCasinoBets;

    // Events to log important contract actions
    event CasinoBetPlaced(
        uint256 nonce, 
        address indexed indexedUser, address user, 
        address indexed indexedCasinoGameContract, address casinoGameContract, 
        uint256 indexed indexedBetAmount, uint256 betAmount,
        bytes betParameters
    );

    /**
     * @notice Allows users to place a sports bet
     * @dev Internal function to place a sports bet using the SportsConnector contract.
     *      Only callable by the placeSportsBet() function throughout all smart contracts.
     * @param _betAmount Amount of USDT to bet.
     * @param _betParameters Parameters required to place the bet.
     */
    function _placeCasinoBet(
        address _casinoGameContract,
        uint256 _betAmount,
        bytes calldata _betParameters
    ) internal {
        uint256 _nonce;
        try ICasinoGameContract(_casinoGameContract).play(_betParameters) returns (
            uint256 nonce
        ) {
            _nonce = nonce;

            activeCasinoBets[_nonce] = ActiveCasinoBet({
                user: msg.sender,
                casinoGameContract: _casinoGameContract,
                betAmount: _betAmount,
                betParameters: _betParameters,
                betPlacedAt: block.timestamp
            });
        } catch (bytes memory) {
            revert("Failed to place casino bet.");
        }
        
        emit CasinoBetPlaced(_nonce, msg.sender, msg.sender, _casinoGameContract, _casinoGameContract, _betAmount, _betAmount, _betParameters);
    }
}
