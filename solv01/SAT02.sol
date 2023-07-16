// Solidity SAT contract that uses the LINK AnyAPI pricefeed to set its price:

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeed {
    function getPrice() external view returns (uint256);
}

contract StableCoin {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;

    uint256 public constant TARGET_PRICE = 100 * 10 ** 18; // $100 in wei

    IPriceFeed public priceFeed1;
    IPriceFeed public priceFeed2;
    IPriceFeed public priceFeed3;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _priceFeedAddress1, address _priceFeedAddress2, address _priceFeedAddress3) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        priceFeed1 = IPriceFeed(_priceFeedAddress1);
        priceFeed2 = IPriceFeed(_priceFeedAddress2);
        priceFeed3 = IPriceFeed(_priceFeedAddress3);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function getLatestPrice() public view returns (uint256) {
        uint256 price1 = getPriceFromFeed1();
        uint256 price2 = getPriceFromFeed2();
        uint256 price3 = getPriceFromFeed3();

        uint256 averagePrice = (price1 + price2 + price3) / 3;

        // Calculate the multiplier to reach $100
        uint256 priceMultiplier = TARGET_PRICE * (10 ** decimals) / averagePrice;

        // Convert the aggregated price to represent $100
        uint256 adjustedPrice = averagePrice * priceMultiplier;

        return adjustedPrice;
    }

    function getPriceFromFeed1() internal view returns (uint256) {
        return priceFeed1.getPrice();
    }

    function getPriceFromFeed2() internal view returns (uint256) {
        return priceFeed2.getPrice();
    }

    function getPriceFromFeed3() internal view returns (uint256) {
        return priceFeed3.getPrice();
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
}

/** 
The mint() function - before minting, the function checks whether the current price is greater than or equal to 
the target price. If it's not, the function reverts with the error message "Price is below target". If the price 
is above the target price, the function calculates a priceMultiplier based on the price difference, and mints an 
amount of stablecoins equal to priceMultiplier * 10 ** decimals (where decimals is the number of decimal places 
for this stablecoin)
*/
