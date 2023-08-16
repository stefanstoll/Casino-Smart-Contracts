// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "UserRewards" Contract (Construction In Progress)
 * @author Stefan Stoll, stefan@transpare.io
 * @dev This contract provides logic to handle the user rewards program.
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

contract UserRewards is IOwnable {
    uint256 public minimumRewardToClaim = 5e6; // ($5)

    mapping(address => uint256) public userRewards; // User addresses to their rewards earned

    event RewardClaimed(address indexed user, uint256 amount);
    event MinimumRewardToClaimUpdated(uint256 _newMinimumRewardToClaim);

    /**
     * @notice Internal claim user reward function
     */
    function _claimUserReward() internal {
        require(userRewards[msg.sender] > minimumRewardToClaim, "Rewards t0o small to claim"); // Check if the reward meets the min requirement.
        
        emit RewardClaimed(msg.sender, userRewards[msg.sender]);
    }

    /**
     * @notice Updates the Transpare team wallet
     * @param _newMinimumRewardToClaim New Transpare team wallet
     */
    function updateMinimumRewardToClaim(uint256 _newMinimumRewardToClaim) external onlyOwner {
        minimumRewardToClaim = _newMinimumRewardToClaim;

        emit MinimumRewardToClaimUpdated(_newMinimumRewardToClaim);
    }
}
