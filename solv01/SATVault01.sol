
// This vault contract accepts Bitcoin (BTC) and PAX Gold (PAXG) as collateral and 
// uses a seperate LINK Any-API pricefeed to mint the SAT stablecoin

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SATPriceFeed.sol";
import "./SAT01.sol";

contract Vault {
    AnyAPIPriceFeed public priceFeed;
    Stablecoin public stablecoin;

    uint256 public constant COLLATERALIZATION_RATIO = 150; // minimum 150% collateralization
    uint256 public constant LIQUIDATION_THRESHOLD = 120; // liquidation threshold at 120% collateralization

    mapping(address => uint256) public balances;
    mapping(address => bool) public isCollateral;

    constructor(address _priceFeed, address _stablecoin) {
        priceFeed = AnyAPIPriceFeed(_priceFeed);
        stablecoin = Stablecoin(_stablecoin);

        isCollateral[0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599] = true; // BTC
        isCollateral[0x45804880De22913dAFE09f4980848ECE6EcbAf78] = true; // PAXG
     // In this example, the Vault contract only accepts BTC and PAXG as collateral, as specified by the `is
    }

    /*
    Allows users to lock their collateral and receive the equivalent amount of stablecoin (DAI) 
    based on the collateralization ratio. The function checks whether the specified collateral 
    is valid and has a price available. It then calculates the value of the collateral and ensures 
    that there is enough stablecoin available in the contract. If everything checks out, the user's 
    balance is updated and they receive their stablecoin.
    */
    function lock(address _collateral, uint256 _amount) public {
        require(isCollateral[_collateral], "Invalid collateral");
        require(priceFeed.getPrice(_collateral) > 0, "Price not available");
        uint256 collateralValue = priceFeed.getPrice(_collateral) * _amount / 1e18;
        uint256 daiAmount = collateralValue * COLLATERALIZATION_RATIO / 100;
        require(stablecoin.balanceOf(address(this)) >= daiAmount, "Not enough Dai available");
        balances[msg.sender] += _amount;
        require(stablecoin.transfer(msg.sender, daiAmount), "Failed to transfer Dai");
    }


    /*
    Allows users to unlock their collateral by sending back the equivalent amount of stablecoin 
    to the contract. The function checks whether the specified collateral is valid and that the 
    user has enough balance. If everything checks out, the user's balance is updated and the stablecoin 
    is transferred back to the contract.
    */ 
    function unlock(address _collateral, uint256 _amount) public {
        require(isCollateral[_collateral], "Invalid collateral");
        require(balances[msg.sender] >= _amount, "Insufficient collateral balance");
        balances[msg.sender] -= _amount;
        require(stablecoin.transferFrom(msg.sender, address(this), _amount), "Failed to transfer Dai");
    }


    /*
    Allows anyone to liquidate an account if their collateralization ratio falls below the  
    liquidation threshold. The function checks whether the account's collateral value is below the  
    liquidation threshold and burns the equivalent amount of stablecoin based on the collateralization ratio.
    */

    function liquidate(address _account) public {
        uint256 collateralValue = getCollateralValue(_account);
        require(collateralValue < stablecoin.balanceOf(address(this)) * LIQUIDATION_THRESHOLD / 100, "Collateral above liquidation threshold");
        balances[_account] = 0;
        stablecoin.burn(collateralValue * 100 / COLLATERALIZATION_RATIO);
    }


    /*
    Calculates the total value of a user's collateral by looping through the accepted collateral 
    types and checking if the user has a balance for that type. If the user has a balance, the function 
    calculates the value of the collateral based on the price feed and adds it to the total value
    */
    function getCollateralValue(address _account) public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint i = 0; i < 2; i++) {
            address collateral = i == 0 ? 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 : 0x45804880De22913dAFE09f4980848ECE6EcbAf78; // BTC and PAXG
            if (balances[_account] > 0 && isCollateral[collateral]) {
                uint256 collateralValue = priceFeed.getPrice(collateral) * balances[_account] / 1e18;
                totalValue += collateralValue;
            }
        }
        return totalValue;
    }
}

// In this example, the Vault contract only accepts BTC and PAXG as collateral, as specified by the `isCollateral
