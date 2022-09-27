// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IAdAuction } from './IAdAuction.sol';
import { PriceOracle } from './PriceOracle.sol';

contract AdAuction {
    
    using PriceOracle for uint256;

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

    constructor(uint256 _startAuctionTime, uint256 _endAuctionTime, uint256 _minimumUsdBid) {
        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumUsdBid = _minimumUsdBid * 1e18;
    }

    function payForAd(string calldata _name, string calldata _imageUrl, string calldata _text) payable external {
        require(startAuctionTime <= block.timestamp, "AdAuction::payForAd: The auction hasn't started yet");
        require(endAuctionTime >= block.timestamp, "AdAuction::payForAd: The auction is already over");
        
        require(msg.value.getConversionRate() > minimumUsdBid, "AdAuction::payForAd: Ad bid is lower than minium auction bin in USD");
        
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

}