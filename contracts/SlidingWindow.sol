// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "SlidingWindow" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev Implements a SlidingWindow mechanism to provide a robust and agile liquidity management system.
 *
 *      The SlidingWindow concept is utilized to divide a continuous time frame into discrete windows of fixed duration.
 *      Each window captures balance fluxuation and allows for the continuous monitoring of liquidity changes.
 *
 *      This contract supports two types of Sliding Windows: LiquidityPool and Casino.
 *      - LiquidityPool: Manages the USDT allocated to CasinoLP holders.
 *      - Casino: Manages the total USDT the contract holds, including LiquidityPool and the sum of user balances.
 *
 *      The adjustable parameters for each type enable tailored monitoring and control according to specific requirements.
 *      By tracking liquidity continuously, the SlidingWindow serves as a safeguard, providing a shield against significant exploits.
 *      In the unlikely event of a failure or attack, this mechanism contributes to preserving system stability and protecting user assets.
 * 
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

// Enum defining the two supported sliding window types:
// - LiquidityPool: Represents the USDT allocated to CasinoLP holders.
// - Casino: Represents the total USDT the contract holds (LiquidityPool + sum of user balances).
enum WindowType { LiquidityPool, Casino }

contract SlidingWindow is IOwnable {
    // Structure to define sliding window configuration
    struct WindowConfig {
        uint256 windowSize;                    // Fixed window duration in seconds.
        uint256 windowShiftSize;               // Fixed shift duration within the window in seconds.
        uint8 numberOfIntervals;               // Fixed number of intervals in the window.
        uint256 initialWindowStartTime;        // Fixed initial start time of the window.
        uint256 initialWindowEndTime;          // Fixed initial end time of the window.
        uint256 windowPeriodStartTime;         // Dynamic start time of the current window.
        uint256 windowPeriodEndTime;           // Dynamic end time of the current window.
        uint256 windowPeriodStartBalance;      // Dynamic start balance of the current window in USDT.
        uint8 thresholdPercentage;             // Fixed threshold percentage for monitoring abnormal drops (e.g., 20%).
        uint8 lastUpdatedIndex;                // Dynamic index of the last updated interval.
        uint256[] intervalStartBalanceHistory; // Dynamic history of start balances for each interval.
    }

    // Mappings to manage the active state and configurations for each sliding window type
    mapping(WindowType => bool) public isSlidingWindowActive;
    mapping(WindowType => WindowConfig) internal windowConfigs;

    // Events to notify changes related to SlidingWindows
    event SlidingWindowEnabled(WindowType windowType);
    event SlidingWindowDisabled(WindowType windowType);

    /**
     * @notice Updates a sliding window's state, handling shifts and balance updates.
     * @dev Called internally to handle shifts and updates within a sliding window.
     *      Manages the window period and balances, shifts the window if necessary, 
     *      and ensures alignment with the current time.
     * @param _windowType Type of the sliding window.
     * @param _proposedBalance Proposed balance for the update.
     */
    function _updateWindow(WindowType _windowType, uint256 _proposedBalance) internal {
        WindowConfig storage config = windowConfigs[_windowType];

        // Check if the current time exceeds the end of the initial window period plus one shift size (just for optimization)
        if (block.timestamp >= config.initialWindowEndTime + config.windowShiftSize) {
            // Determine the number of shifts needed to realign the window with the current time
            uint256 _shiftsNeeded = (block.timestamp - config.windowPeriodEndTime) / config.windowShiftSize;

            // If shifts are needed, update the window period start and end times
            if (_shiftsNeeded > 0) {
                // If a whole window of shifts was missed, restart the sliding window
                if (_shiftsNeeded >= config.numberOfIntervals) {
                    // We do not want to use the _proposedBalance, instead pull a trusted previous balance
                    uint256 _windowPeriodStartBalance = config.intervalStartBalanceHistory[0];
                    _disableSlidingWindow(_windowType);
                    uint8 _thresholdPercentage;
                    if (_windowType == WindowType.LiquidityPool) {
                        _thresholdPercentage = 20;
                    } else {
                        _thresholdPercentage = 40;
                    }
                    _enableSlidingWindow(_windowType, 8 * 60 * 60, 2 * 60 * 60, _windowPeriodStartBalance, _thresholdPercentage);
                } else {
                    // Shift the window period start time forward by the required number of shifts
                    config.windowPeriodStartTime += _shiftsNeeded * config.windowShiftSize;
                    // Recalculate the window period end time based on the new start time
                    config.windowPeriodEndTime = config.windowPeriodStartTime + config.windowSize;

                    uint256 _oldestIntervalIndex = (config.lastUpdatedIndex + _shiftsNeeded) % config.numberOfIntervals;
                    config.windowPeriodStartBalance = config.intervalStartBalanceHistory[_oldestIntervalIndex];

                    // Update missed interval start balances for all missed shifts
                    for (uint256 i = 1; i <= _shiftsNeeded; i++) {
                        config.intervalStartBalanceHistory[(_oldestIntervalIndex + i) % config.numberOfIntervals] = _proposedBalance;
                    }
                }
            }
        }

        // Calculate the current interval index based on the time elapsed since the initial window start
        uint256 _rawCurrentIntervalIndex = (block.timestamp - config.initialWindowStartTime) / config.windowShiftSize;
        // Normalize the raw interval index to fit within the number of intervals defined
        uint8 _currentIntervalIndex = uint8(_rawCurrentIntervalIndex % config.numberOfIntervals);

        // Check if we are in a new interval since the last update
        if (_rawCurrentIntervalIndex != config.lastUpdatedIndex) {
            // Store the given balance in the intervalStartBalanceHistory array
            config.intervalStartBalanceHistory[_currentIntervalIndex] = _proposedBalance;
            // Update the last interval index to the current one, indicating an update was made
            config.lastUpdatedIndex = _currentIntervalIndex;
        }
    }

    /**
     * @notice Configures and enables a sliding window.
     * @param _windowType Type of the sliding window (LiquidityPool or Casino).
     * @param _windowSize Size of the window in seconds.
     * @param _windowShiftSize Shift size within the window in seconds.
     * @param _currentBalance Initial balance for the window in USDT
     * @param _thresholdPercentage Threshold percentage for monitoring abnormal drops (e.g., 20%).
     */
    function _enableSlidingWindow(WindowType _windowType, uint256 _windowSize, uint256 _windowShiftSize, uint256 _currentBalance, uint8 _thresholdPercentage) internal {
        require(!isSlidingWindowActive[_windowType], "Sliding window is active");
        require(_windowSize % _windowShiftSize == 0, "Size % ShiftSize must be 0");
        require(_windowShiftSize > 0, "Shift size can't be 0");
        require(_windowSize > _windowShiftSize, "Window size not > shift size");
        require(_thresholdPercentage <= 100, "Threshold % must be < 100");

        WindowConfig storage config = windowConfigs[_windowType];

        // Set up # of intervals
        uint256 _numberOfIntervals = _windowSize / _windowShiftSize;
        config.numberOfIntervals = uint8(_numberOfIntervals);
        config.intervalStartBalanceHistory = new uint256[](_numberOfIntervals);
        for (uint8 i = 0; i < _numberOfIntervals; i++) {
            config.intervalStartBalanceHistory[i] = _currentBalance;
        }
        config.lastUpdatedIndex = 0;

        // Set the config with parameters given
        config.windowSize = _windowSize;
        config.windowShiftSize = _windowShiftSize;
        config.windowPeriodStartBalance = _currentBalance;
        config.thresholdPercentage = _thresholdPercentage;

        // Set the window start time and end time with timestamps
        config.initialWindowStartTime = block.timestamp;
        config.initialWindowEndTime = config.initialWindowStartTime + config.windowSize;
        config.windowPeriodStartTime = block.timestamp;
        config.windowPeriodEndTime = config.windowPeriodStartTime + config.windowSize;

        // Activate the SlidingWindow
        isSlidingWindowActive[_windowType] = true;

        emit SlidingWindowEnabled(_windowType);
    }

    /**
     * @notice Disables the casino's sliding window protection tool based on the given window type.
     * @param _windowType The type of window to disable (either LiquidityPool or Casino).
     */
    function disableSlidingWindow(WindowType _windowType) external onlyOwner {
        _disableSlidingWindow(_windowType);
    }

    /**
     * @notice Disables a sliding window.
     * @param _windowType Type of the sliding window (LiquidityPool or Casino).
     */
    function _disableSlidingWindow(WindowType _windowType) internal {
        require(isSlidingWindowActive[_windowType], "Sliding window is not active");
        
        // Restet the configuration associated with the sliding window type
        delete windowConfigs[_windowType];
        // Deactivate the SlidingWindow
        isSlidingWindowActive[_windowType] = false;

        emit SlidingWindowDisabled(_windowType);
    }
}
