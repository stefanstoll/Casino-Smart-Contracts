// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "CoinFlip" Contract
 * @author Stefan Stoll
 * @dev Represents a coin flip game where players bet on the outcome of a coin toss.
 *      Utilizes a verifiable random function (VRF) from the SupraRouter for game outcome.
 *      Only the main casino contract can initiate a game. The contract also has administrative
 *      capabilities like pausing the game.
 */

pragma solidity ^0.8.0;

// Audited OpenZeppelin libraries for contract security and access management.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @dev This contract utilizes Supra VRF for its randomness generation.
 * Supra VRF offers the following benefits:
 * - It employs a distributed VRF (DVRF) ensuring that no single node holds the entire private key. The key is shared cryptographically secure such that T+1 out of N nodes collectively hold it, but any T or fewer nodes have no information about it.
 * - The VRF output is generated collectively by at least T+1 nodes using their respective key shares. This VRF output can be aggregated publicly, and the verification process remains the same, whether produced by a DVRF or centralized VRF.
 * - Supra's implementation, based on the GLOW construction, provides robustness against partial signature manipulations by utilizing Zero-knowledge Proofs (ZKP) to validate each partial signature.
 * - To ensure the VRF's availability, a corruption threshold 'T' is set such that 'N' is at least 2T+1. This guarantees that even if T nodes are compromised, T+1 honest nodes can compute the VRF correctly.
 * - While DVRF has some computational and communication overheads compared to centralized VRF, the enhanced security benefits justify these trade-offs.
 */
interface ISupraRouter {
    /**
     * @notice Generates a VRF request.
     * @param _functionSig Callback function signature.
     * @param _rngCount # of requested random numbers.
     * @param _requiredConfirmations Number of confirmations to consider the request final.
     * @param _clientWalletAddress Transpare's wallet address that pays for VRF service.
     * @return The nonce of the generated VRF request.
     */
    function generateRequest(
        string memory _functionSig,
        uint8 _rngCount,
        uint256 _requiredConfirmations,
        address _clientWalletAddress
    ) external returns (uint256);
}

interface ICasinoBase {
    /**
     * @notice Notifies the casino about the result of a game.
     * @param _nonce Nonce of the game.
     * @param _multiplier Payout multiplier.
     */
    function notifyGameResult(uint256 _nonce, uint256 _multiplier) external;
}

contract CoinFlip is Ownable, Pausable {
    uint8 public constant WIN_MULTIPLIER = 200; // CoinFlip win multiplier
    uint8 private constant GET_SINGLE_RANDOM_NUM = 1; // Request only one random number from VRF.
    uint8 private constant HEADS = 0; // Heads is set to the value of "0" (I do not like Enums)
    uint8 private constant TAILS = 1; // Tails is set to the value of "1" (I do not like Enums)

    address public casinoAddress; // Only address that can play the CoinFlip game.
    uint256 private requiredConfirmations = 1; // Required block confirmations before VRF request is considered final.
    address public supraRouterAddress; // SupraOracle's router address for VRF.
    address private clientWalletAddress; // Transpare's wallet address that pays for VRF service.

    // Maps the VRF nonce to the enum of the user's guess (HEADS or TAILS).
    // Once the game's outcome is determined, the corresponding entry is removed.
    mapping(uint256 => uint8) public activeUserGuesses;

    // Events to log key contract actions
    event CoinFlipGameStarted(uint256 nonce, uint8 userGuess);
    event CoinFlipGameResult(uint256 nonce, string userGuess, string coinResult, uint256 multiplier);
    event ActiveUserGuessDeleted(uint256 indexed nonce, uint8 userGuess);
    event RequiredConfirmationsUpdated(uint256 newRequiredConfirmations);
    event CasinoAddressUpdated(address newCasinoAddress);
    event ClientWalletAddressUpdated(address newClientWalletAddress);
    event SupraRouterAddressUpdated(address newSupraRouterAddress);

    /**
     * @dev Modifier ensuring calls only come from the VRF provider (SupraRouter).
     */
    modifier onlySupraRouter() {
        require(msg.sender == supraRouterAddress, "Only VRF SupraRouter can execute");
        _;
    }

    /**
     * @dev Modifier ensuring calls only come from the main casino contract.
     */
    modifier onlyCasino() {
        require(msg.sender == casinoAddress, "Only the main casino can execute");
        _;
    }

    /**
     * @notice Contract constructor sets the initial configurations for the game.
     * @param _casinoAddress Address of the main casino.
     * @param _supraRouterAddress Address of the VRF provider.
     * @param _clientWalletAddress Address paying for the VRF service.
     */
    constructor(
        address _casinoAddress,
        address _supraRouterAddress,
        address _clientWalletAddress
    ) {
        casinoAddress = _casinoAddress;
        supraRouterAddress = _supraRouterAddress;
        clientWalletAddress = _clientWalletAddress;
    }

    /**
     * @notice Begins a CoinFlip game round for a player.
     * @dev Validates the player's choice from the last byte of betParameters and makes a VRF request.
     *      The last byte of betParameters should be either 0 (HEADS) or 1 (TAILS).
     * @param _betParameters The last byte of betParameters represents the user's bet choice.
     * @return nonce Unique identifier for the game round provided by the SupraRouter.
     */
    function play(
        bytes calldata _betParameters
    ) external onlyCasino whenNotPaused returns (uint256) {
        require(_betParameters.length == 1, "Parameters must be 1 byte");
        uint8 _userGuess = uint8(_betParameters[0]);
        require(
            _userGuess == HEADS || _userGuess == TAILS,
            "Must be HEADS (0) or TAILS (1)"
        );

        // No need to check for duplicated nonces. SupraRouter generated nonces are always unique
        uint256 _nonce = ISupraRouter(supraRouterAddress).generateRequest(
            "handleVRFResult(uint256,uint256[])",
            GET_SINGLE_RANDOM_NUM,
            requiredConfirmations,
            clientWalletAddress
        );

        activeUserGuesses[_nonce] = _userGuess;

        emit CoinFlipGameStarted(_nonce, _userGuess);

        return _nonce;
    }

    /**
     * @notice Computes the CoinFlip result using the VRF output and notifies the casino about the game's outcome.
     * @dev Uses the provided nonce from the SupraRouter to retrieve the player's choice and then
     *      compares it with the VRF outcome to decide the game result.
     * @param _nonce Unique identifier for the game round provided by the SupraRouter.
     * @param _rngList Random numbers from VRF.
     */
    function handleVRFResult(
        uint256 _nonce,
        uint256[] calldata _rngList
    ) external onlySupraRouter whenNotPaused {
        require(_rngList.length == 1, "Expecting a single random number");

        uint8 _rawUserGuess = activeUserGuesses[_nonce];
        uint8 _rawCoinResult = uint8(_rngList[0] % 2);
        uint8 _rawMultiplier = (_rawUserGuess == _rawCoinResult) ? WIN_MULTIPLIER : 0;

        string memory _userGuess = (_rawUserGuess == 0) ? "Heads" : "Tails";
        string memory _coinResult = (_rawCoinResult == 0) ? "Heads" : "Tails";

        emit CoinFlipGameResult(_nonce, _userGuess, _coinResult, _rawMultiplier);

        delete activeUserGuesses[_nonce];

        ICasinoBase(casinoAddress).notifyGameResult(_nonce, _rawMultiplier);
    }

    // Admin Functions
    // This function allows the owner to delete a failed user guess. Will only be called after the failed bet is returned to the user first
    function deleteActiveUserGuess(uint256 _nonce) external onlyOwner {
        require(activeUserGuesses[_nonce] == HEADS || activeUserGuesses[_nonce] == TAILS, "Active user guess not found");

        emit ActiveUserGuessDeleted(_nonce, activeUserGuesses[_nonce]);

        delete activeUserGuesses[_nonce];
    }

    function setRequiredConfirmations(uint256 _requiredConfirmations) external onlyOwner {
        require(_requiredConfirmations > 0, "Confirmations should be > 0");
        requiredConfirmations = _requiredConfirmations;
        emit RequiredConfirmationsUpdated(_requiredConfirmations);
    }

    function setCasino(address _newAddress) external onlyOwner {
        require(_newAddress != address(0) && _newAddress != casinoAddress, "Invalid/unchanged address");
        casinoAddress = _newAddress;
        emit CasinoAddressUpdated(_newAddress);
    }

    function setClientWallet(address _newAddress) external onlyOwner {
        require(_newAddress != address(0) && _newAddress != clientWalletAddress, "Invalid/unchanged address");
        clientWalletAddress = _newAddress;
        emit ClientWalletAddressUpdated(_newAddress);
    }

    function setSupraRouter(address _newAddress) external onlyOwner {
        require(_newAddress != address(0) && _newAddress != supraRouterAddress, "Invalid/unchanged address");
        supraRouterAddress = _newAddress;
        emit SupraRouterAddressUpdated(_newAddress);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
