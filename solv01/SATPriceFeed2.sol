//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

//  @Dev remember any contracts using LINK need to be funded after they are deployed
//  after fund run requestMultiparameters 


contract MultiCommoditiesFeed is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    uint256 private fee;

    // multiple params returned in a single oracle response
    uint256 public btc;
    uint256 public gold;
    uint256 public oil;

    event RequestMultipleFulfilled(
        bytes32 indexed requestId,
        uint256 btc,
        uint256 gold,
        uint256 oil
    );

    /**
     * @dev Initialize the link token and target oracle
     * @dev The oracle address must be an operator contract for multiword 
     * response/orchastration to run 
     *
     * Sepolia Testnet details:
     * LINK: 0x779877A7B0D9E8603169DdbD7836e478b4624789  (Payto contract)
     * Oracle: 0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD (Chainlink DevRel)
     * jobId: 53f9755920cd451a8fe46f5087468395
     *
     */
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "53f9755920cd451a8fe46f5087468395";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }
    /**
     * @dev Request mutiple parameters from the oracle in a single transaction
     * requestMultipleParameters function builds the Chainlink.Request 
     * it tells the LINK oracle where to fetch the price in the json response. 
     * The URLs and paths, in this contract call any public API as long as
     * the URLs and paths are copacetic
     */
     
    function requestMultipleParameters() public {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        //feed 1 BTC
        req.add(
            "urlBTC",
            "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD&api_key=a61fc21ec8d4ace963b1c38c3b9378ff7bac83507ae2b3b9036fc5dd98dd994d"
            // "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"
            // The BTC to USD price URL w/ my cryptocompare key
        );
        req.add("pathBTC", "BTC");
        
        // feed 2 Gold via PAXG
         req.add(
            "urlGOLD",
            "https://min-api.cryptocompare.com/data/price?fsym=PAXG&tsyms=USD&api_key=a61fc21ec8d4ace963b1c38c3b9378ff7bac83507ae2b3b9036fc5dd98dd994d"
         );
         req.add("pathGOLD", "GOLD");

        // feed 3 Oil
        req.add(
            "urlOIL",
            "https://commodities-api.com/api/latest?access_key=ho90ir8l3777dymv9s6vzblbt5p34udvu3bqub662168au23b963x0gzq7kg"
         );
         req.add("pathOIL", "OIL");
         req.add("pathOIL", "x.data.rates.BRENTOIL");

        sendChainlinkRequest(req, fee); // MWR API.
    }

    /**
     * @dev Fulfillment function for multiple parameters in a single request
     * This is called by the oracle. recordChainlinkFulfillment must be used.
     */

    function fulfillMultipleParameters(
        bytes32 requestId,
        uint256 btcResponse,
        uint256 goldResponse,
        uint256 oilResponse
         ) 
    public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(
            requestId,
            btcResponse,
            goldResponse,
            oilResponse
        );
        btc = btcResponse;
        gold = goldResponse;
        oil = oilResponse;
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/  /  https://docs.chain.link/resources/acquire-link
 * Find information on LINK Token Contracts and get the latest ETH + LINK faucets: https://docs.chain.link/docs/link-token-contracts/
 * Ref: https://docs.chain.link/any-api/get-request/examples/multi-variable-responses/ 
 */
