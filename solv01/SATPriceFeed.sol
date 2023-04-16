/**
Contract uses LINK Any-API to aggregate the prices of Bitcoin, Gold, and Crude Oil into one 
price that a stablecoin contract can use for minting:
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// LINK contract functions borrowed to run this contract 
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract PriceAggregator is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    LinkTokenInterface internal link;
    AggregatorV3Interface internal bitcoinAggregator;
    AggregatorV3Interface internal goldAggregator;
    AggregatorV3Interface internal crudeOilAggregator;

    uint256 public constant DECIMALS = 10 ** 18;


constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee, address _bitcoinAggregator, address _goldAggregator, address _crudeOilAggregator)
        VRFConsumerBase(_vrfCoordinator, _fee)
    {
        keyHash = _keyHash;
        fee = _fee;
        link = LinkTokenInterface(_link);
        bitcoinAggregator = AggregatorV3Interface(_bitcoinAggregator);
        goldAggregator = AggregatorV3Interface(_goldAggregator);
        crudeOilAggregator = AggregatorV3Interface(_crudeOilAggregator);
    }

/**
The getPrice() function calls the latestRoundData() function of each  AggregatorV3Interface contract 
to get the current price of each asset. It then weights each price by a predetermined percentage (40% 
for Bitcoin, 30% for Gold, and 30% for Crude Oil), multiplies each weighted price by the DECIMALS
*/

    function getPrice() public view returns (uint256) {
        uint256 bitcoinPrice = uint256(getLatestPrice(bitcoinAggregator));
        uint256 goldPrice = uint256(getLatestPrice(goldAggregator));
        uint256 crudeOilPrice = uint256(getLatestPrice(crudeOilAggregator));

        uint256 weightedBitcoinPrice = bitcoinPrice * DECIMALS * 40 / 100;
        uint256 weightedGoldPrice = goldPrice * DECIMALS * 30 / 100;
        uint256 weightedCrudeOilPrice = crudeOilPrice * DECIMALS * 30 / 100;

        uint256 aggregatedPrice = weightedBitcoinPrice + weightedGoldPrice + weightedCrudeOilPrice;

        return aggregatedPrice / DECIMALS;
    }

    function requestRandomness() public returns (bytes32) {
        require(link.balanceOf(address(this)) >= fee, "Not enough LINK to fulfill request");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        // do nothing
    }

    function getLatestPrice(AggregatorV3Interface _aggregator) internal view returns (int256) {
        (, int256 price, , , ) = _aggregator.latestRoundData();
        return price;
    }
}
