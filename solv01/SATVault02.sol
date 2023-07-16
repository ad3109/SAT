// This vault contract uses a seperate LINK Any-API pricefeed to mint the SAT stablecoin
// This contract also uses exteral API to monitor collateral to protect users

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ICollateralAvailabilityAPI.sol";
import "./SATPriceFeed.sol";
import "./SAT02.sol";

interface IPriceFeed {
    function getPrice(address _collateral) external view returns (uint256);
}

interface ICollateralAvailabilityAPI {
    function getCollateralAvailability() external view returns (uint256);
}

// Collateral checkers from outside APIs which would allow liquidation to protect users below

contract Vault {
    AnyAPIPriceFeed public priceFeed;
    Stablecoin public stablecoin;
    IPriceFeed public priceFeed0;
    ICollateralAvailabilityAPI public collateralAvailabilityAPI;

    uint256 public constant COLLATERALIZATION_RATIO = 150; // minimum 150% collateralization
    uint256 public constant LIQUIDATION_THRESHOLD = 101; // liquidation threshold at 101% collateralization
// Liquidate at 101% to protect clients from losing their money

    mapping(address => uint256) public balances;
    mapping(address => bool) public isCollateral;

     // In this example, the Vault contract only accepts the below stablecoins, as specified by `isCollateral’
     // The final version should call a diamond/proxy that will allow the addition of future commodity tokens like oil

    constructor(address _priceFeed, address _stablecoin, address _priceFeed0, address _collateralAvailabilityAPI) {
        priceFeed0 = IPriceFeed(_priceFeed0);
        collateralAvailabilityAPI = ICollateralAvailabilityAPI(_collateralAvailabilityAPI);
        priceFeed = AnyAPIPriceFeed(_priceFeed);
        stablecoin = Stablecoin(_stablecoin);

	isCollateral[0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599] = true; // BTC
	isCollateral[0x45804880De22913dAFE09f4980848ECE6EcbAf78] = true; // PAXG
   	isCollateral[0x93E9Dc9b41bB37A3E85A3Bf5EC39C8C437D03126] = true; // PMGT
  	isCollateral[0x4922a015c4407F87432B179bb209e125432E4a2A] = true; // XAUT
	isCollateral[0xdAC17F958D2ee523a2206206994597C13D831ec7] = true; // USDT
	isCollateral[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = true; // USDC
  	isCollateral[0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56] = true; // BUSD
  	isCollateral[0x0000000000085d4780B73119b644AE5ecd22b376] = true; // TUSD
 	isCollateral[0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd] = true; // GUSD
 	isCollateral[0x1456688345527bE1f37E9e627DA0837D6f08C925] = true; // USDP
  	isCollateral[0xdF574c24545E5FfEcb9a659c229253D4111d87e1] = true; // HUSD
    }

    /*
    Allows users to lock their collateral and receive the equivalent amount of stablecoin (SAT) 
    based on the collateralization ratio. The function checks whether the specified collateral 
    is valid and has a price available. It then calculates the value of the collateral and ensures 
    that there is enough stablecoin available in the contract. If everything checks out, the user's 
    balance is updated and they receive their stablecoin. 
    */

function lock(address _collateral, uint256 _amount) public {
    require(isCollateral[_collateral], "Invalid collateral");
    require(priceFeed.getPrice(_collateral) > 0, "Price not available");
    uint256 collateralValue = priceFeed.getPrice(_collateral) * _amount / 1e18;
    uint256 satAmount = collateralValue * COLLATERALIZATION_RATIO / 100;
    uint256 requiredSatAmount = satAmount * 150 / 100; // Adjusted for 150% collateralization ratio
    require(stablecoin.balanceOf(address(this)) >= requiredSatAmount, "Not enough SAT available");
    balances[msg.sender] += _amount;
    require(stablecoin.transfer(msg.sender, requiredSatAmount), "Failed to transfer SAT");
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
    uint256 burnFee = _amount * 3 / 100; // Calculate the 3% burn fee
    uint256 unlockAmount = _amount - burnFee; // Calculate the remaining unlocked collateral amount
    require(stablecoin.transferFrom(msg.sender, address(this), _amount), "Failed to transfer SAT");
    require(stablecoin.burn(burnFee), "Failed to burn SAT"); 
    require(stablecoin.transfer(msg.sender, unlockAmount), "Failed to transfer unlocked SAT");
}

    /*
    Allows anyone to liquidate an account if their collateralization ratio falls below the  
    liquidation threshold. The function checks whether the account's collateral value is below the  
    liquidation threshold and burns the equivalent amount of stablecoin based on the collateralization ratio.
    */

function liquidate(address _account) public {
    uint256 collateralValue = getCollateralValue(_account);
    uint256 liquidationThreshold = stablecoin.balanceOf(address(this)) * LIQUIDATION_THRESHOLD / 100;
    require(collateralValue < liquidationThreshold, "Collateral above liquidation threshold");
    balances[_account] = 0;
    uint256 satToBurn = collateralValue * 100 / COLLATERALIZATION_RATIO;
    if (satToBurn > stablecoin.balanceOf(address(this))) {
        satToBurn = stablecoin.balanceOf(address(this));
    }
    stablecoin.transferFrom(_account, address(this), satToBurn);
    stablecoin.burn(satToBurn);
}

   function getCurrentCollateralAvailability() public view returns (uint256) {
        return collateralAvailabilityAPI.getCollateralAvailability();
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
// AS NOTED: the final vault version will allow all major fiat and commodity backed stablecoins as collateral
