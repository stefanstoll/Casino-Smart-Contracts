// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "SportsBet" Contract
 * @author Stefan Stoll, Stefan@Transpare.io
 * @dev This contract facilitates sports betting by allowing users to place bets and forwarding them to the sports connector.
 */

pragma solidity ^0.8.0;

// Provides ownership control, enabling only the owner to perform certain operations.
import "./IOwnable.sol";

// Defines the interface for interacting with the sports connector contract.
interface ISportsConnector {
    /**
     * @notice Facilitates placing a sports bet.
     * @dev The function interfaces with the sports connector to place a sports bet.
     * @param _betParameters Parameters for the sports bet.
     */
    function relaySportsBet(bytes calldata _betParameters) external;
}

contract SportsBet is IOwnable {
    address public sportsConnectorContract; // Address of the contract that enables sports betting

    // Stores a sports bet
    struct ActiveSportsBet {
        uint256 betAmount;   // Bet amount in USDT.
        bytes betParameters; // Parameters of the bet (e.g., teams, odds).
        uint256 timestamp;   // Timestamp when the bet was placed.
    }

    // Mapping to associate user addresses with their sports bets.
    mapping(address => mapping(uint256 => ActiveSportsBet)) public sportsBetsByUser;
    // Mapping to keep track of the number of bets for each user.
    mapping(address => uint256) private userBetCount;
    
    // Event triggered when a new sports bet is placed.
    event SportsBetPlaced(
        address indexed indexedUser, address _user, 
        uint256 indexed indexedBetAmount, uint256 betAmount,
        bytes betParameters
    );
    // Event triggered when the sports connector contract address is updated.
    event SportsConnectorContractUpdated(address newSportsConnectorContract);

    /**
     * @notice Allows users to place a sports bet
     * @dev Internal function to place a sports bet using the SportsConnector contract.
     *      Only callable by the placeSportsBet() function throughout all smart contracts.
     * @param _betAmount Amount of USDT to bet.
     * @param _betParameters Parameters required to place the bet.
     */
    function _placeSportsBet(
        uint256 _betAmount,
        bytes calldata _betParameters
    ) internal {
        try
            ISportsConnector(sportsConnectorContract).relaySportsBet(_betParameters)
        {
            uint256 betID = userBetCount[msg.sender]++;
            ActiveSportsBet storage activeSportsBet = sportsBetsByUser[msg.sender][betID];
            activeSportsBet.betAmount = _betAmount;
            activeSportsBet.betParameters = _betParameters;
            activeSportsBet.timestamp = block.timestamp;
        } catch (bytes memory) {
            revert("Failed to place sports bet.");
        }
        
        emit SportsBetPlaced(msg.sender, msg.sender, _betAmount, _betAmount, _betParameters);
    }

    /**
     * @notice Updates the address of the SportsConnector contract.
     * @param _newSportsConnectorContract New address of the sports connector contract.
     */
    function updateSportsConnectorContract(address _newSportsConnectorContract) external onlyOwner {
        require(_newSportsConnectorContract != address(0), "Invalid address");
        
        sportsConnectorContract = _newSportsConnectorContract;

        emit SportsConnectorContractUpdated(_newSportsConnectorContract);
    }
}
