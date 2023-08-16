// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "CasinoGameContracts" Contract
 * @author Stefan Stoll, Stefan@Transpare.io
 * @dev This contract enables the management/authentication of different casino game contracts within a larger system.
 *      It provides functionalities to add or remove game contracts and ensures that only authenticated game contracts can interact with the system.
 *      Note: The array gameContractAddresses is used solely to return a list of all authenticated contracts. The mapping casinoGameContracts is what we use for logic everywhere.
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

// Interface for interacting with external casino game contracts.
interface ICasinoGameContract {
    /**
     * @notice Facilitates placing a bet in casino games.
     * @dev Function is expected to handle the logic for casino game bet placement and return a unique identifier for the bet.
     * @param _betParameters Data needed to place a casino bet.
     * @return nonce Unique identifier for the game round/bet.
     */
    function play(bytes calldata _betParameters) external returns (uint256 nonce);
}

contract CasinoGameContracts is IOwnable {
    // Mapping of game contract addresses to their authentication status.
    // Used to quickly check if a game contract is authenticated.
    mapping(address => bool) public casinoGameContracts;

    // Array of game contract addresses used for user convenience
    // by allowing the listing of all authenticated game contracts.
    address[] private listOfAllCasinoGameContracts;

    /**
     * @dev Modifier ensuring calls only come from authenticated game contracts.
     *      Used for callbacks to provide game results from authenticated game contracts.
     */
    modifier onlyCasinoGameContract() {
        require(casinoGameContracts[msg.sender], "Caller not authenticated");
        _;
    }

    // Emitted when a game contract is authenticated.
    event CasinoGameContractAdded(address indexed casinoGameContract);
    // Emitted when an authenticated game contract is removed.
    event CasinoGameContractRemoved(address indexed casinoGameContract);

    /**
     * @notice Authenticates a new game contract.
     * @dev Adds the game contract to the mapping (system) and the list of addresses, and triggers an event.
     *      Requires that the contract address is valid and not already authenticated.
     * @param _casinoGameContract Address of the game contract to authenticate.
     */
    function addCasinoGameContract(address _casinoGameContract) external onlyOwner {
        require(_casinoGameContract != address(0), "Invalid game contract address");
        require(!casinoGameContracts[_casinoGameContract], "Game already authenticated");

        // Add to the mapping
        casinoGameContracts[_casinoGameContract] = true;

        // Add to the array
        listOfAllCasinoGameContracts.push(_casinoGameContract);

        emit CasinoGameContractAdded(_casinoGameContract);
    }

    /**
     * @notice Removes an authenticated game contract.
     * @dev Removes the game contract from the mapping (system) and the list of addresses, and triggers an event.
     *      Requires that the contract address is already authenticated.
     * @param _casinoGameContract Address of the game contract to remove.
     */
    function removeCasinoGameContract(address _casinoGameContract) external onlyOwner {
        require(casinoGameContracts[_casinoGameContract], "Game contract not found");

        // Remove from mapping
        delete casinoGameContracts[_casinoGameContract];
        
        // Remove from the array
        for (uint8 i = 0; i < listOfAllCasinoGameContracts.length; i++) {
            if (listOfAllCasinoGameContracts[i] == _casinoGameContract) {
                listOfAllCasinoGameContracts[i] = listOfAllCasinoGameContracts[listOfAllCasinoGameContracts.length - 1];
                listOfAllCasinoGameContracts.pop();
                break;
            }
        }

        emit CasinoGameContractRemoved(_casinoGameContract);
    }

    /**
     * @notice Provides a list of all authenticated contracts.
     * @dev This extra function just allows users to be able to see a full list
     *      of all of the current authenticated game contracts for transparency.
     */
    function getAllAuthenticatedCasinoGameContracts() external view returns (address[] memory) {
        return listOfAllCasinoGameContracts;
    }
}
