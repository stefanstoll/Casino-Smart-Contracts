// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Importing required contracts and interfaces from OpenZeppelin library
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IProxyFront {
    struct BetParameters {
        address dataAddress;
        uint256 dataValue;
    }

    function bet(address lp, BetParameters[] memory data) external;
}

contract SportsConnector is Ownable, Pausable {
    using SafeERC20 for IERC20;

    // State variables for the contract
    address public casino;
    IERC20 public usdtToken;
    IProxyFront public proxyFront;
    uint256 public proxyFrontAllowance;

    struct UserBet {
        address user;
        uint256 amount;
        IProxyFront.BetParameters betParameters;
    }

    mapping(bytes32 => UserBet) public activeBets;

    event AzuroAllowanceChanged(uint256 allowance);

    /**
     * @dev Modifier to restrict function execution to only the main casino contract.
     */
    modifier onlyCasino() {
        require(msg.sender == casino, "Only casino can call");
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _casino Address of the main casino contract.
     * @param _usdtToken Address of the USDT token contract.
     * @param _proxyFront Address of the Azuro ProxyFront contract.
     */
    constructor(address _casino, address _usdtToken, address _proxyFront) {
        require(_casino != address(0), "Invalid Casino contract address");
        require(_usdtToken != address(0), "Invalid USDT token address");
        require(_proxyFront != address(0), "Invalid Azuro contract");

        casino = _casino;
        usdtToken = IERC20(_usdtToken);
        proxyFront = IProxyFront(_proxyFront);
        proxyFrontAllowance = 0;
    }

    /**
     * @dev Relays the sports bet to the appropriate contract.
     * @param _data Encoded bytes containing the user's address, bet amount, and bet data.
     */
    function relaySportsBet(
        bytes memory _data
    ) external whenNotPaused onlyCasino {
        (
            address user,
            uint256 amount,
            IProxyFront.BetParameters[] memory betParameters
        ) = abi.decode(_data, (address, uint256, IProxyFront.BetParameters[]));

        proxyFront.bet(user, betParameters);

        // Store this bet in active bets mapping
        activeBets[
            keccak256(abi.encodePacked(block.number, user, amount))
        ] = UserBet({
            user: user,
            amount: amount,
            betParameters: betParameters[0] // Assuming one bet for simplicity. Adjust for multiple bets.
        });
    }

    /**
     * @dev Withdraws USDT from the contract in case there are stuck funds.
     * @param to Address to transfer USDT to.
     * @param amount Amount of USDT to transfer.
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        usdtToken.safeTransfer(to, amount);
    }

    /**
     * @dev Changes the USDT allowance for the ProxyFront contract.
     * @param _newProxyFrontAllowance New USDT allowance for the ProxyFront contract.
     */
    function changeAllowance(
        uint256 _newProxyFrontAllowance
    ) external onlyOwner {
        usdtToken.approve(address(proxyFront), _newProxyFrontAllowance);
        proxyFrontAllowance = _newProxyFrontAllowance;

        emit AzuroAllowanceChanged(_newProxyFrontAllowance);
    }

    /**
     * @dev Pauses the game.
     */
    function pauseGame() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the game.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
