// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "Defense" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev This contract adds security measures to withdrawal actions.
 *      It includes a sliding window mechanism to watch and monitor the liquidity balance and overall balance of the contract.
 *      When very extreme withdrawal patterns are detected, there is a chance high-risk mode can be activated.
 */

pragma solidity ^0.8.0;

// Transpare contracts that are being inherited
import "./SlidingWindow.sol"; // Sliding window mechanism.
import "./HighRiskWithdraw.sol"; // High risk logic and withdraw procedures.

contract Defense is SlidingWindow, HighRiskWithdraw {
    uint8 internal thresholdToRestrict = 5; // % below the allowedBalance to restrict a user;

    mapping(address => bool) internal restrictedAddresses; // Mapping of restricted addresses
 
    // Modifier to check if the caller is not restricted
    modifier whenNotRestricted() {
        require(!restrictedAddresses[msg.sender], "Address is restricted");
        _;
    }

    // Event to log defense actions
    event SlidingWindowTriggered(WindowType windowType, uint256 proposedBalance, uint256 allowedBalance, bool wasUserRestricted);
    event AddressRestricted(address indexed target);
    event AddressUnrestricted(address indexed target);

    /**
     * @notice Checks the sliding window mechanism and takes action if needed.
     * @param _windowType Window type to consider (LiquidityProvider or Casino).
     * @param _user The address of the user initiating the withdrawal request.
     * @param _proposedBalance The proposed balance after the withdrawal, reflecting the state if the withdrawal were to proceed.
     * @dev If the proposed balance is VERY extreme, high-risk mode can be activated.
     */
    function _checkSlidingWindow(WindowType _windowType, address _user, uint256 _proposedBalance) internal {
        // Update the sliding window
        _updateWindow(_windowType, _proposedBalance);
        // Get sliding window configurations (LP, Casino)
        WindowConfig memory _config = windowConfigs[_windowType];
        // Get balance that contract shouldn't go under using sliding window
        uint256 _allowedBalance = (_config.windowPeriodStartBalance * (100 - _config.thresholdPercentage)) / 100;

        if (_proposedBalance <= _allowedBalance) {
            // Logic that restricts a user if an attempted withdrawal caused the balance to take an EXTREME change
            // Note: Address will be unrestricted immediately if no wrong doing, just a big withdrawal
            // Note: For BIG withdrawals (> 25% of the entire casino balance), if you give the team a heads up
            // Note: we can disable defense mechanisms for a smooth withdrawal process.
            bool _wasUserRestricted = false;
            if (_allowedBalance == 0 || (_proposedBalance * 100) / _allowedBalance < (100 - thresholdToRestrict)) {
                _restrictAddress(_user);
                _wasUserRestricted = true;
            }
            _enableHighRiskMode();
            _disableSlidingWindow(_windowType);
            emit SlidingWindowTriggered(_windowType, _proposedBalance, _allowedBalance, _wasUserRestricted);
        }
    }

    /**
     * @notice Restricts an address manually
     * @param _addressToRestrict The address to restrict
     */
    function restrictAddress(address _addressToRestrict) external onlyOwner {
        _restrictAddress(_addressToRestrict);
    }

    /**
     * @notice Internal function to restrict an address.
     * @param _address The address to be restricted.
     */    
    function _restrictAddress(address _address) internal {
        restrictedAddresses[_address] = true;
        emit AddressRestricted(_address);
    }

    /**
     * @notice Allows the owner to unrestrict an address.
     * @param _address The address to be unrestricted.
     */
    function unrestrictAddress(address _address) public onlyOwner {
        restrictedAddresses[_address] = false;
        emit AddressUnrestricted(_address);
    }

    /**
     * @notice Checks if an address is restricted.
     * @param _address The address to check.
     * @return true if the address is restricted, false otherwise.
     */
    function isAddressRestricted(address _address) public view returns (bool) {
        return restrictedAddresses[_address];
    }
    
    /**
     * @notice Sets a new threshold to restrict an address.
     * @param _newThresholdToRestrict The new threshold value.
     * @dev Change how much the balance must drop below the allowed balance for a user to be restricted (ex. 5 => 5%)
     */    
    function setThresholdToRestrict(uint8 _newThresholdToRestrict) public onlyOwner {
        require(_newThresholdToRestrict >= 0 && _newThresholdToRestrict <= 100, "Threshold not 0 <= x <= 100");
        thresholdToRestrict = _newThresholdToRestrict;
    }
}
