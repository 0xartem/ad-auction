// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IAdAuction } from './IAdAuction.sol';
import { PriceOracle } from './PriceOracle.sol';

contract AdAuction {
    
    using PriceOracle for uint256;

    error NotOwner();
    
    error InvalidAuctionPeriod();
    error AuctionHasntStartedYet();
    error AuctionIsOver();
    error AuctionIsNotOverYet();

    error InvalidMinimumBidRequirement();
    error BidIsLowerThanMinimum();

    error NoSuchPayer();
    error HighestBidderCantWithdraw();
    error BidderAlreadyWithdrew();
    error BidWithdrawalFailed();
    
    error NothingToWithdraw();
    error OwnerWithdrawalFailed();

    struct Payer {
        string name;
        uint256 amount;
        string imageUrl;
        string text;
        bool withdrew;
    }

    address public owner;
    
    uint256 public startAuctionTime;
    uint256 public endAuctionTime;
    uint256 public minimumUsdBid;

    address public highestBidderAddr;
    mapping (address => Payer) public addressToPayer;

    constructor(uint256 _startAuctionTime, uint256 _endAuctionTime, uint256 _minimumUsdBid) {
        owner = msg.sender;

        if (_endAuctionTime <= _startAuctionTime) revert InvalidAuctionPeriod();
        if (_minimumUsdBid < 0) revert InvalidMinimumBidRequirement();

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumUsdBid = _minimumUsdBid * 1e18;
    }

    function payForAd(string calldata _name, string calldata _imageUrl, string calldata _text) payable external {
        if (block.timestamp < startAuctionTime) revert AuctionHasntStartedYet();
        if (block.timestamp > endAuctionTime) revert AuctionIsOver();
        if (msg.value.getConversionRate() < minimumUsdBid) revert BidIsLowerThanMinimum();
        if (msg.value <= addressToPayer[highestBidderAddr].amount) revert HigherBidIsAvailable();
        
        Payer storage payer = addressToPayer[msg.sender];
        if (payer.amount == 0) {
            payer = Payer(_name, msg.value, _imageUrl, _text, false);
        } else {
            payer.amount += msg.value;
        }
        highestBidderAddr = msg.sender;
    }

    // todo: implement logic so you can withdraw not all but a part depending on how long your ad was up
    function withdrawBid(address receiver) external {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        if (msg.sender == highestBidderAddr) revert HighestBidderCantWithdraw();

        Payer memory payer = addressToPayer[msg.sender];
        if (payer.amount == 0) revert NoSuchPayer();
        if (payer.withdrew) revert BidderAlreadyWithdrew();

        delete addressToPayer[msg.sender];

        (bool res, ) = receiver.call{ value: payer.amount}(""); // convert to payable?
        if (!res) revert BidWithdrawalFailed();
    }

    function withdraw(address receiver) external onlyOwner {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        if (address(this).balance == 0) revert NothingToWithdraw();

        (bool res, ) = receiver.call{ value: address(this).balance}("");
        if (!res) revert OwnerWithdrawalFailed();
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
    }
}