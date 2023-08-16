// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "OutcomeDistribution" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @notice This contract is responsible for managing the distribution of losses in the Transpare system. 
 *         It allows for the configuration of how losses are allocated among LP Holders, Transpare, UserRewards, and Lottery.
 */

pragma solidity ^0.8.0;

// Provides ownership control (OpenZeppelin), enabling only the owner to perform certain operations.
import "./IOwnable.sol";

contract OutcomeDistribution is IOwnable {
    struct LossDistribution {
        uint16 toLPHolders; // amount to LP holders (ex. 970 => 97%)
        uint16 toTranspare; // amount to Transpare
        uint16 toUserRewards; // amount to UserRewards
        uint16 toLottery; // amount to Lottery
    }
    
    LossDistribution public lossDistribution;

    constructor() {
        lossDistribution = LossDistribution(970, 20, 7, 3);
    }

    function updateDistribution(uint16 toLPHolders, uint16 toTranspare, uint16 toUserRewards, uint16 toLottery) external onlyOwner {
        require(toLPHolders + toTranspare + toUserRewards + toLottery == 1000, "Values must add up to 1000");

        lossDistribution.toLPHolders = toLPHolders;
        lossDistribution.toTranspare = toTranspare;
        lossDistribution.toUserRewards = toUserRewards;
        lossDistribution.toLottery = toLottery;
    }
}
