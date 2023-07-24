//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * DO NOT USE THIS CODE IN PRODUCTION.
 * XAU = Gold, XAG = Silver, WTI = Oil (price mime)
 */

contract SATMultiAsset1 is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    uint256 private fee;

    // multiple params returned in a single oracle response
    uint256 public btc;
    uint256 public xau;
    uint256 public xag;
    uint256 public wti;

    event RequestMultipleFulfilled(
        bytes32 indexed requestId,
        uint256 btc,
        uint256 xau,
        uint256 xag,
        uint256 wti
    );

    /**
     * @notice Initialize the link token and target oracle
     * @dev The oracle address must be an Operator contract for multiword response
     *
     * This contract uses Goerli, LTC MIMES WTI here
     * Sepolia Testnet details:
     * Link Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789
     * Oracle: 0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD (Chainlink DevRel)
     * jobId: 53f9755920cd451a8fe46f5087468395
     *
     */
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        // call uint256 output: https://docs.chain.link/any-api/testnet-oracles
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /**
     * @notice Request mutiple parameters from the oracle in a single transaction
     */
    function requestMultipleParameters() public {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        req.add(
            "urlBTC",
            "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"
        );
        req.add("pathBTC", "BTC");

        req.add(
            "urlXAU",
            "https://min-api.cryptocompare.com/data/price?fsym=PAXG&tsyms=USD"
        );
        req.add("pathXAU", "XAU");

        req.add(
            "urlXAG",
            "https://min-api.cryptocompare.com/data/price?fsym=XAG&tsyms=USD"
        );
        req.add("pathXAG", "XAG");

        req.add(
            "urlWTI",
            "https://min-api.cryptocompare.com/data/price?fsym=LTC&tsyms=USD"
        );
        req.add("pathWTI", "WTI");

        sendChainlinkRequest(req, fee); // MWR API.
    }

    /**
     * @notice Fulfillment function for multiple parameters in a single request
     * @dev This is called by the oracle. recordChainlinkFulfillment must be used.
     */
    function fulfillMultipleParameters(
        bytes32 requestId,
        uint256 btcResponse,
        uint256 xauResponse,
        uint256 xagResponse,
        uint256 wtiResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(
            requestId,
            btcResponse,
            xauResponse,
            xagResponse,
            wtiResponse
        );
        btc = btcResponse;
        xau = xauResponse;
        xag = xagResponse;
        wti = wtiResponse;
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
