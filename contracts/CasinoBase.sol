// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "CasinoBase" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev This contract enables users to interact with Transpare's casino and sports betting services.
 *      It manages users' deposits, withdrawals, and betting actions.
 *      The contract implements various safety mechanisms, such as the safety stop feature, to enhance the security of funds and operations.
 *      Further, the contract is designed to be upgradeable, allowing the addition/removal of game contracts and adjustment of key parameters like house edge.
 *      Note: Think of it like a casino headquarters.
 */

pragma solidity ^0.8.0;

// Audited OpenZeppelin libraries for secure token transfers, reentrancy protection, and safety mechanism.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// Transpare contracts that are being inherited
import "./LiquidityProvider.sol"; // Liquidity pool functionality.
import "./SportsBet.sol"; // Sports integration.
import "./CasinoBet.sol"; // Casino game contracts access management.
import "./Defense.sol"; // Protective layer against potential exploits.
import "./UserRewards.sol"; // User rewards system.
import "./Lottery.sol"; // Lottery system.
import "./OutcomeDistribution.sol"; // Outcome distribution.
import "./CasinoSettings.sol"; // Casino settings.

contract CasinoBase is LiquidityProvider, Defense, CasinoBet, SportsBet, UserRewards, Lottery, OutcomeDistribution, CasinoSettings, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    IERC20 public usdtToken;

    // Public state variables
    uint256 public casinoUSDTUserBalance; // Total amount of USDT in user balances

    // Mappings to manage user balances, liquidity provider balances, and active games
    mapping(address => uint256) public userBalance; // User addresses to their deposited balances

    // Events to log important contract actions
    event CasinoBetResult(
        uint256 nonce, 
        address indexed indexedUser, address user, 
        address indexed indexedCasinoGameContract, address casinoGameContract, 
        uint256 betAmount, 
        uint256 winAmount,
        uint256 indexed indexedMultiplier, uint256 multiplier
    );
    event Deposit(
        address indexed indexedUser, address user,
        uint256 indexed indexedDepositAmount, uint256 depositAmount
    );
    event Withdrawal(
        address indexed indexedUser, address user, 
        uint256 indexed indexedWithdrawAmount, uint256 withdrawAmount
    );
    event ManualGameSettlement(uint256 indexed nonce, address indexed user, uint256 indexed betAmount, bool awardBetBack);

    /**
     * @notice Constructor to set up initial configurations.
     * @param _usdtToken Address of the USDT token contract.
     */
    constructor(
        IERC20 _usdtToken
    ) {
        require(address(_usdtToken) != address(0), "Invalid USDT token address");
        usdtToken = _usdtToken;
    }

    /**
     * @notice Allows users to deposit USDT into the casino.
     * @param _depositAmount Amount of USDT to deposit (6 decimals).
     */
    function deposit(uint256 _depositAmount) external whenNotPaused nonReentrant whenNotRestricted {
        require(_depositAmount > 0, "Deposit should be > 0");

        usdtToken.safeTransferFrom(msg.sender, address(this), _depositAmount);
        userBalance[msg.sender] += _depositAmount;
        casinoUSDTUserBalance += _depositAmount;

        emit Deposit(msg.sender, msg.sender, _depositAmount, _depositAmount);
    }

    /**
     * @notice Allows users to withdraw USDT from the casino.
     * @dev Bad actors will be automatically prevented from withdrawing by by our defense systems
     * in the unlikely case there was an exploit in the code and they attempt to take advantage
     * @param _withdrawAmount Amount of USDT to withdraw (6 decimals).
     */
    function withdraw(uint256 _withdrawAmount) external whenNotPaused nonReentrant whenNotRestricted {
        require(userBalance[msg.sender] >= _withdrawAmount, "Insufficient balance");
        require(_withdrawAmount > 0, "Amount should be > than 0");

        if (isSlidingWindowActive[WindowType.Casino] && !highRiskMode) {
            // Check sliding window defensive mechanism
            uint256 _proposedBalance = usdtToken.balanceOf(address(this)) - _withdrawAmount;
            _checkSlidingWindow(WindowType.Casino, msg.sender, _proposedBalance);
        }

        // Note From the Author:
        // if (highRiskMode) acts as the contracts liquidity protector and is only activated when the contract is at extremely high risk conditions (<0.1% of the time).
        // If this occurs, the team has to check and make sure the contract isn't being exploited. highRiskMode should almost never be activated and if it is, the team will disable it asap. 
        // When highRiskMode is activated, withdrawals are capped at a safe amount. Check docs for more info.
        if (highRiskMode) {
            // check if withdrawal follows withdrawal limits during a high risk period
            // withdraw will revert if it doesn't
            _withdrawFromHighRiskPool(_withdrawAmount);
        }

        // Normal flow (unlimited withdrawal amounts)
        userBalance[msg.sender] -= _withdrawAmount;
        casinoUSDTUserBalance -= _withdrawAmount;
        usdtToken.safeTransfer(msg.sender, _withdrawAmount);

        emit Withdrawal(msg.sender, msg.sender, _withdrawAmount, _withdrawAmount);
    }

    function addLiquidity(uint256 _depositInUSDT) external whenNotPaused nonReentrant whenNotRestricted {
        require(!highRiskMode, "High risk on, try again soon");
        require(userBalance[msg.sender] >= _depositInUSDT, "Insufficient user balance");
        require(_depositInUSDT > 0, "Amount should be greater than 0");
        
        userBalance[msg.sender] -= _depositInUSDT;
        casinoUSDTUserBalance -= _depositInUSDT;

        _addLiquidity(_depositInUSDT);
    }

    function removeLiquidity(uint256 _withdrawalInLP) external whenNotPaused nonReentrant whenNotRestricted {
        require(!highRiskMode, "High risk on, try again soon");
        require(_withdrawalInLP > 0, "Amount should be greater than 0");
        
        uint256 _withdrawalInUSDT = _removeLiquidity(_withdrawalInLP);

        if (isSlidingWindowActive[WindowType.LiquidityPool]) {
            // Check sliding window defensive mechanism
            uint256 _proposedBalance = casinoUSDTLiquidityBalance - _withdrawalInUSDT;
            _checkSlidingWindow(WindowType.LiquidityPool, msg.sender, _proposedBalance);
        }
        
        userBalance[msg.sender] += _withdrawalInUSDT;
        casinoUSDTUserBalance += _withdrawalInUSDT;
    }

    /**
     * @notice Allows users to place a casino bet
     * @dev Only authenticated game contract can be called.
     * @param _casinoGameContract Address of the game contract.
     * @param _betAmount Amount of USDT to bet.
     * @param _betParameters Data required to place the bet.
     */
    function placeCasinoBet(
        address _casinoGameContract,
        uint256 _betAmount,
        bytes calldata _betParameters
    ) external whenNotPaused nonReentrant whenNotRestricted {
        require(_betParameters.length <= maxBytesLength, "Bet parameters too long");
        require(casinoGameContracts[_casinoGameContract], "Game contract not authenticated");
        require(userBalance[msg.sender] >= _betAmount, "Insufficient balance");
        require(_betAmount > 0, "Bet should be greater than 0");
        require(_betAmount <= (casinoUSDTLiquidityBalance * maxBetPercentage) / 1000, "Bet amount too high");

        userBalance[msg.sender] -= _betAmount;
        casinoUSDTUserBalance -= _betAmount;

        _placeCasinoBet(_casinoGameContract, _betAmount, _betParameters);
    }

    /**
     * @notice Handles the result of a game and adjusts user balances and casino liquidity accordingly.
     * @dev This function is responsible for managing the distribution of winning and losing bets. It calculates
     *      the winnings and losses according to the multiplier and applies the house edge to winning bets only.
     * @param _nonce Unique identifier for the bet, used to fetch the relevant bet details.
     * @param _multiplier Represents the multiplier scaled by 100 (ex. 350 => 3.50x, 24 => 0.24x)
     */
    function notifyGameResult(
        uint256 _nonce,
        uint256 _multiplier
    ) external whenNotPaused onlyCasinoGameContract whenNotRestricted {
        address _user = activeCasinoBets[_nonce].user;
        require(_user != address(0), "Game not found");
        uint256 _betAmount = activeCasinoBets[_nonce].betAmount;
        uint256 _winAmount;
        if (_multiplier == 0) {
            // Losing Bet (Multiplier == 0): Of the bet, return a split of the bet between LP Holders, Transpare, UsersRewards, and the Lottery
            _winAmount = 0;
            casinoUSDTLiquidityBalance += (_betAmount * lossDistribution.toLPHolders) / 1000; // amount to LP holders (ex. 970 => 97%)
            userBalance[transpareWallet] += (_betAmount * lossDistribution.toTranspare) / 1000; // amount to Transpare.
            userRewards[_user] += (_betAmount * lossDistribution.toUserRewards) / 1000; // amount to UserRewards.
            lotteryBalance += (_betAmount * lossDistribution.toLottery) / 1000; // amount to Lottery.
            casinoUSDTUserBalance += (_betAmount * (1 - lossDistribution.toLPHolders)) / 1000;
        } else if (_multiplier <= 100) {
            // Partial Losing Bet (Multiplier <= 1): Distribute the bet amount minus the win amount to the casino and the win amount to the user.
            _winAmount = (_betAmount * _multiplier) / 100;

            // Add only the loss portion to casinoUSDTLiquidityBalance, which is the bet amount minus the win amount.
            casinoUSDTLiquidityBalance += (_betAmount - _winAmount); 
            userBalance[_user] += _winAmount;
            casinoUSDTUserBalance += _winAmount;
        } else {
            // Winning Bet (Multiplier > 1): Calculate the win amount after adjusting for the house edge.
            // Remove the house edge from the raw multiplier (ex. 200 => 196)
            uint256 _adjustedMultiplier = (_multiplier * (1e7 - (houseEdge * 1e4)))/100;
            _winAmount = (_betAmount * _adjustedMultiplier) / 1e7;
            uint256 _profitAmount = _winAmount - _betAmount;

            if (isSlidingWindowActive[WindowType.LiquidityPool] && !highRiskMode) {
                // Check sliding window defensive mechanism
                uint256 _proposedBalance = casinoUSDTLiquidityBalance - _profitAmount;
                _checkSlidingWindow(WindowType.LiquidityPool, _user, _proposedBalance);
            }

            // Update liqudity balance by considering only the profit portion.
            casinoUSDTLiquidityBalance -= _profitAmount; 
            // Update user balance by considering the entire win amount.
            userBalance[_user] += _winAmount;
            casinoUSDTUserBalance += _winAmount;
        }

        emit CasinoBetResult(_nonce, _user, _user, msg.sender, msg.sender, _betAmount, _winAmount, _multiplier, _multiplier);

        delete activeCasinoBets[_nonce];
    }

    /**
     * @notice Allows the owner to settle an active game manually and return a failed bet to the user.
     * @dev This function should only be called in case of a failure in the game settlement process.
     * @param _nonce Unique identifier for the game.
     * @param _awardBetBack If user should get back their original bet (T/F)
     */
    function manuallySettleCasinoBet(uint256 _nonce, bool _awardBetBack) external onlyOwner {
        ActiveCasinoBet memory bet = activeCasinoBets[_nonce];

        require(bet.user != address(0), "Game not found");
        // Check if it has been over 2 minutes since the bet was placed => means there was a malfunction.
        require(block.timestamp >= bet.betPlacedAt + 2 minutes, "2 minutes haven't passed");

        if (_awardBetBack) {
            // Credit the user's balance with the original bet amount
            userBalance[bet.user] += bet.betAmount;
            casinoUSDTUserBalance += bet.betAmount;
        }

        delete activeCasinoBets[_nonce]; // Remove the bet from activeCasinoBets mapping

        emit ManualGameSettlement(_nonce, bet.user, bet.betAmount, _awardBetBack);
    }

    /**
     * @notice Allows users to place a sports bet
     * @dev Processes sports bet using the SportsConnector contract.
     * @param _betAmount Amount of USDT to bet.
     * @param _betParameters Parameter required to place the bet.
     */
    function placeSportsBet(uint256 _betAmount, bytes calldata _betParameters) external whenNotPaused nonReentrant whenNotRestricted {
        require(_betParameters.length <= maxBytesLength, "Bet parameters too long");
        require(userBalance[msg.sender] >= _betAmount, "Insufficient balance");
        require(_betAmount > 0, "Bet should be greater than 0");
        require(!highRiskMode, "High risk on, try again soon");

        userBalance[msg.sender] -= _betAmount;
        casinoUSDTUserBalance -= _betAmount;

        _placeSportsBet(_betAmount, _betParameters);
    }

    // Function called by the owner to add the lottery reward to the winning user's balance
    function awardLottery(address _winningAddress) external onlyOwner {
        _awardLottery(_winningAddress); // Call internal lottery function
        userBalance[_winningAddress] += lotteryBalance; // Add the lotteryBalance to the user's balance
        lotteryBalance = 0; // Reset the lotteryBalance
    }
    
    // Function called by a user to claim their accumulated rewards
    function claimUserReward() external whenNotPaused nonReentrant whenNotRestricted {
        _claimUserReward();
        userBalance[msg.sender] += userRewards[msg.sender]; // Add the reward to the user's balance
        userRewards[msg.sender] = 0; // Reset the user's reward
    }

    /**
     * @notice Corrects the casino balance if there is a mismatch with the actual USDT balance
     * @dev It checks if the sum of total user balances and casino balance matches the contract's USDT balance.
     *      If there is a mismatch, it recalculates the casino balance by subtracting the total user balances
     *      from the contract's USDT balance, thereby ensuring consistency with the actual balance on-chain.
     *      Note: This function should never have to be used
     */
    function correctCasinoUSDTLiquidityBalance() external onlyOwner {
        if (casinoUSDTUserBalance + casinoUSDTLiquidityBalance != usdtToken.balanceOf(address(this))) {
            casinoUSDTLiquidityBalance = usdtToken.balanceOf(address(this)) - casinoUSDTUserBalance;
        }
    }

    /**
     * @notice Enables the casino's sliding window protection tool based on the given window type.
     * @param _windowType The type of window to enable (either LiquidityPool or Casino).
     */
    function enableSlidingWindow(WindowType _windowType, uint256 _windowSize, uint256 _windowShiftSize, uint8 _thresholdPercentage) external onlyOwner {
        uint256 _currentBalance = (_windowType == WindowType.LiquidityPool) ? casinoUSDTLiquidityBalance : usdtToken.balanceOf(address(this));
        _enableSlidingWindow(_windowType, _windowSize, _windowShiftSize, _currentBalance, _thresholdPercentage);
    }
}
