// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @title Transpare "LiquidityProvider" Contract
 * @author Stefan Stoll, stefan@transpare.io
 * @dev CasinoLP (cLP) represents a share of the total liquidity in the pool.
 *      Users can deposit USDT to mint CasinoLP tokens and can burn CasinoLP tokens to withdraw USDT.
 *      This contract handles the conversion between CasinoLP and USDT, and manages the liquidity for the casino's operations.
 */

pragma solidity ^0.8.0;

// Audited OpenZeppelin libraries for token creation and secure token transfers.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityProvider is ERC20("CasinoLP", "cLP") {
    // Public state variables
    uint256 public casinoUSDTLiquidityBalance = 0; // Balance of USDT that backs CasinoLP tokens (6 decimal places).

    // Events to log liquidity changes
    event LiquidityAdded(
        address indexed indexedUser, address user,
        uint256 indexed indexedDepositInLP, uint256 depositInLP, 
        uint256 indexed indexedDepositInUSDT, uint256 depositInUSDT
    );
    event LiquidityRemoved(
        address indexed indexedUser, address user,
        uint256 indexed indexedWithdrawInLP, uint256 withdrawtInLP, 
        uint256 indexed indexedWithdrawInUSDT, uint256 withdrawInUSDT
    );

    /**
     * @notice Internal function to add liquidity to the contract.
     * @param _depositInUSDT Amount of USDT to add to liquidity pool (6 decimals).
     */
    function _addLiquidity(uint256 _depositInUSDT) internal {
        // If it's the first deposit, mint CasinoLP tokens at a 1:1 ratio with USDT.
        // This establishes the initial conversion rate for the liquidity pool.
        // Otherwise, calculate the equivalent amount of CasinoLP tokens based on the current liquidity pool's value.
        // The conversion rate is determined by the ratio of total CasinoLP tokens to the total USDT balance in the pool.
        uint256 _depositInLP = (totalSupply() == 0) 
        ? _depositInUSDT * 1e12 
        : _depositInUSDT * totalSupply() / casinoUSDTLiquidityBalance;

        // Increase the casino balance.
        casinoUSDTLiquidityBalance += _depositInUSDT;

        // Mint the CasinoLP tokens for the depositor.
        _mint(msg.sender, _depositInLP);

        emit LiquidityAdded(msg.sender, msg.sender, _depositInLP, _depositInLP, _depositInUSDT, _depositInUSDT);
    }

    /**
     * @notice Internal function to remove liquidity from the contract.
     * @param _withdrawalInLP Amount of CasinoLP tokens to withdraw from the liquidity pool (18 decimal places).
     * @return Amount of USDT withdrawn from the liquidity pool.
     */
    function _removeLiquidity(uint256 _withdrawalInLP) internal returns (uint256) {
        require(balanceOf(msg.sender) >= _withdrawalInLP, "Insufficient CasinoLP");
        require(totalSupply() > 0, "No CasinoLP minted yet");

        // Calculate the amount of USDT to withdraw, proportionate to the amount of CasinoLP tokens (6 decimal points).
        uint256 _withdrawalInUSDT = _withdrawalInLP * casinoUSDTLiquidityBalance / totalSupply();

        // Ensure that the withdrawal does not exceed the casino balance.
        require(_withdrawalInUSDT <= casinoUSDTLiquidityBalance, "Exceeds casino balance");

        // Update the casino balance.
        casinoUSDTLiquidityBalance -= _withdrawalInUSDT;

        // Burn the CasinoLP tokens.
        _burn(msg.sender, _withdrawalInLP);

        emit LiquidityRemoved(msg.sender, msg.sender, _withdrawalInLP, _withdrawalInLP, _withdrawalInUSDT, _withdrawalInUSDT);

        return _withdrawalInUSDT;
    }
}
