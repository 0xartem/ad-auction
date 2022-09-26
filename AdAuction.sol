// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IAdAuction } from "./IAdAuction.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AdAuction {

    struct Payer {
        string name;
        uint256 amount;
        string imageUrl;
        string text;
    }

    uint256 startAuctionTime;
    uint256 endAuctionTime;
    uint256 minimumUsdBid;

    address public highestBidderAddr;
    Payer public highestBidderData;
    
    mapping (address => Payer) public addressToPayer;

    AggregatorV3Interface internal priceFeed;

    constructor(uint256 _startAuctionTime, uint256 _endAuctionTime, uint256 _minimumUsdBid) {
        priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e); // Goerli
        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumUsdBid = _minimumUsdBid;
    }

    function payForAd(string calldata _name, string calldata _imageUrl, string calldata _text) payable external {
        require(startAuctionTime <= block.timestamp, "AdAuction::payForAd: The auction hasn't started yet");
        require(endAuctionTime >= block.timestamp, "AdAuction::payForAd: The auction is already over");
        
        uint256 bidInUsd = getConversionRate(msg.value);
        require(bidInUsd > minimumUsdBid, "AdAuction::payForAd: Ad bid is lower than minium auction bin in USD");
        
        if (msg.value > highestBidderData.amount) {
            Payer memory payer = Payer(_name, msg.value, _imageUrl, _text);
            addressToPayer[msg.sender] = payer;
            highestBidderAddr = msg.sender;
        }
    }

    function withdraw(address receiver) external {
        require(startAuctionTime <= block.timestamp, "AdAuction::payForAd: The auction hasn't started yet");
        require(endAuctionTime >= block.timestamp, "AdAuction::payForAd: The auction is already over");
        Payer memory payer = addressToPayer[msg.sender];
        require(payer.amount == 0, "AdAuction::withdraw: No payer available with this address");
        require(msg.sender != highestBidderAddr, "AdAuction::payForAd: Highest bidder cannot withdraw");

        delete addressToPayer[msg.sender];

        (bool res, ) = receiver.call{ value: payer.amount}("");
        require(res, "AdAuction::payForAd: Withdrawal failed");
    }

    function getPrice() public view returns (uint256) {
        uint8 decimals = priceFeed.decimals();
        require(decimals > 0, "AdAuction::getPrice: decimals in the price oracle are wrong");
        
        (,int256 usdPrice,,,) = priceFeed.latestRoundData();
        return uint256(usdPrice) * 1 ** (18 - decimals);
    }

    function getConversionRate(uint256 eth) public view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethInUsd = (ethPrice * usdPrice) / 1e18;
        return ethInUsd;
    }
}