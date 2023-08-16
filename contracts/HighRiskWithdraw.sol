// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "HighRiskWithdraw" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev This contract allows the contract + owner to enable and disable highRiskMode
 *      and configure the limits of the high-risk mode withdrawal pool.
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

contract HighRiskWithdraw is IOwnable {
    // State variable indicating whether high-risk withdrawal mode is active.
    // High-risk mode allows restricted withdrawals according to specific conditions
    // defined by the contract's rules.
    bool public highRiskMode = false;

    // Epoch counter to help reset user balances and manage withdrawal periods
    uint256 private currentEpoch = 0; 

    // Constants for default configuration
    uint256 private constant DEFAULT_POOL_SIZE = 5000 * 1e6; // (5,000 USDT)
    uint256 private constant DEFAULT_PER_USER_WITHDRAWAL_LIMIT = 250 * 1e6; // (250 USDT)

    // Constants for minimum configuration
    uint256 private constant MINIMUM_POOL_SIZE = 1e6; // (1 USDT)
    uint256 private constant MINIMUM_WITHDRAWAL_LIMIT = 1e6; // (1 USDT)

    // Struct to hold high-risk withdraw pool details
    struct HighRiskPool {
        uint256 poolSize; // Total pool size available for withdraw (6 decimals)
        uint256 perUserWithdrawalLimit; // Withdrawal limit per user (6 decimals)
        uint256 totalAmountWithdrawn; // Total amount withdrawn from pool (6 decimals)
    }

    // State variable to hold the current highRiskPool
    HighRiskPool public highRiskPool;

    // Tracks the last withdrawal epoch for each user to manage perUserWithdrawalLimit
    mapping(address => uint256) private userLastWithdrawalEpoch;
    // Tracks the total high-risk withdrawals for each user during the currentEpoch (6 decimals)
    mapping(address => uint256) private userHighRiskWithdrawals;

    // Events to notify changes related to HighRiskPools
    event HighRiskModeEnabled(uint256 poolSize, uint256 perUserWithdrawalLimit, uint256 totalAmountWithdrawn);
    event HighRiskModeDisabled(uint256 poolSize, uint256 perUserWithdrawalLimit, uint256 totalAmountWithdrawn);
    event HighRiskPoolConfigured(uint256 poolSize, uint256 perUserWithdrawalLimit, uint256 totalAmountWithdrawn);

    /**
     * @notice Constructor to initialize default values
     */
    constructor() {
        // Initialization with default values
        highRiskPool = HighRiskPool(DEFAULT_POOL_SIZE, DEFAULT_PER_USER_WITHDRAWAL_LIMIT, 0);
    }

    /**
     * @notice Enables high risk mode manually
     */
    function enableHighRiskMode() external onlyOwner {
        _enableHighRiskMode();
    }

    /**
     * @notice Turn on highRiskMode and start withdrawal pool
     * @dev Can only be called internally and by owner.
     */
    function _enableHighRiskMode() internal {
        require(!highRiskMode, "High risk must not be active");

        currentEpoch++; // Increment epoch to help reset user balances

        // Resets the high risk pool to default values if there hasn't been a manual highRiskPool configuration
        if (highRiskPool.totalAmountWithdrawn > 0) {
            highRiskPool.poolSize = DEFAULT_POOL_SIZE;
            highRiskPool.perUserWithdrawalLimit = DEFAULT_PER_USER_WITHDRAWAL_LIMIT;
            highRiskPool.totalAmountWithdrawn = 0;
        }

        highRiskMode = true; // Turns on high risk conditions
        
        emit HighRiskModeEnabled(highRiskPool.poolSize, highRiskPool.perUserWithdrawalLimit, highRiskPool.totalAmountWithdrawn);
    }

    /**
     * @notice Turn off highRiskMode and stop withdrawal pool
     * @dev Can only be called internally and by owner.
     */
    function disableHighRiskMode() public onlyOwner {
        require(highRiskMode, "High risk must be active");
        
        highRiskMode = false; // Turns off high risk conditions

        emit HighRiskModeDisabled(highRiskPool.poolSize, highRiskPool.perUserWithdrawalLimit, highRiskPool.totalAmountWithdrawn);
    }

    /**
     * @notice Enforce withdrawal limits during highRiskMode
     * @dev The currentEpoch is used to differentiate between withdrawal periods,
     *      and user withdrawals are reset if the last withdrawal was from a previous epoch.
     *      The function ensures that neither the total high-risk pool limit nor the individual
     *      user's limit is exceeded.     
     * @param _amount The amount to withdraw from the highRiskPool (6 decimals)
     */
    function _withdrawFromHighRiskPool(uint256 _amount) internal {
        // Check if total HighRiskPool is exceeded
        require(highRiskPool.poolSize >= highRiskPool.totalAmountWithdrawn + _amount, "Exceeds highRisk withdraw limit");

        // Resets user's withdrawal amounts if they are from a previous epoch
        if (userLastWithdrawalEpoch[msg.sender] < currentEpoch) {
            userHighRiskWithdrawals[msg.sender] = 0;
            userLastWithdrawalEpoch[msg.sender] = currentEpoch;
        }
        // Check if user withdrawal would exceed individual user limit
        require(userHighRiskWithdrawals[msg.sender] + _amount <= highRiskPool.perUserWithdrawalLimit, "Exceeds user pool withdraw limit");

        // Update total and individual user withdrawals
        highRiskPool.totalAmountWithdrawn += _amount;
        userHighRiskWithdrawals[msg.sender] += _amount;
    }

    /**
     * @notice Configure the highRiskPool setup
     * @dev Can only be called by the owner, and only if highRiskMode is not active
     * @param _poolSize Total pool size available for withdrawal (6 decimals)
     * @param _perUserWithdrawalLimit Withdrawal limit per user (6 decimals)
     */
    function configureHighRiskPool(uint256 _poolSize, uint256 _perUserWithdrawalLimit) public onlyOwner {
        require(!highRiskMode, "High risk mode is active");
        require(_poolSize > _perUserWithdrawalLimit, "perUserWithdrawLimit > poolSize");
        require(_poolSize > MINIMUM_POOL_SIZE && _perUserWithdrawalLimit > MINIMUM_WITHDRAWAL_LIMIT, "Inputs must be > $1 in USDT");

        // Update highRiskPool configuration
        highRiskPool.poolSize = _poolSize;
        highRiskPool.perUserWithdrawalLimit = _perUserWithdrawalLimit;
        highRiskPool.totalAmountWithdrawn = 0;

        emit HighRiskPoolConfigured(highRiskPool.poolSize, highRiskPool.perUserWithdrawalLimit, highRiskPool.totalAmountWithdrawn);
    }
}
