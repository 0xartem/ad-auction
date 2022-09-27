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
    error PaidAmountIsLowerThanBid();

    error NoSuchPayer();
    error HighestBidderCantWithdraw();
    error BidderAlreadyWithdrew();
    error BidWithdrawalFailed();
    
    error AdAuctionBalanceIsTooLow();
    error OwnerWithdrawalFailed();

    error NoFundsToCharge();

    struct Payer {
        uint256 ethBalance;
        uint256 ethUsed;
        uint256 blockUsdBid;
        uint256 timeLeft;
        string name;
        string imageUrl;
        string text;
        bool withdrew;
    }

    address public owner;
    
    uint256 public startAuctionTime;
    uint256 public endAuctionTime;
    uint256 public minimumBlockUsdBid;
    uint256 public ownerBalanceAvailable;

    address public highestBidderAddr;
    mapping (address => Payer) public addressToPayer;

    constructor(uint256 _startAuctionTime, uint256 _endAuctionTime, uint256 _minimumBlockUsdBid) {
        owner = msg.sender;

        if (_endAuctionTime <= _startAuctionTime) revert InvalidAuctionPeriod();
        if (_minimumBlockUsdBid == 0) revert InvalidMinimumBidRequirement();

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumBlockUsdBid = _minimumBlockUsdBid * 1e18;
    }

    function payForAd(string calldata _name, string calldata _imageUrl, string calldata _text, uint256 _blockUsdBid) payable external {
        if (block.timestamp < startAuctionTime) revert AuctionHasntStartedYet();
        if (block.timestamp > endAuctionTime) revert AuctionIsOver();

        if (_blockUsdBid <= addressToPayer[highestBidderAddr].blockUsdBid) revert HigherBidIsAvailable();
        if (_blockUsdBid < minimumBlockUsdBid) revert BidIsLowerThanMinimum();
        if (msg.value.convertEthToUsd() < _blockUsdBid) revert PaidAmountIsLowerThanBid();

        Payer storage payer = addressToPayer[msg.sender];
        if (payer.blockUsdBid == 0) {
            // New Payer
            payer = Payer(msg.value, 0, _blockUsdBid, 0, _name, _imageUrl, _text, false);
        } else {
            // Existing Payer
            payer.ethBalance += msg.value;
            payer.blockUsdBid = _blockUsdBid;
            payer.name = _name;
            payer.imageUrl = _imageUrl;
            payer.text = _text;
            payer.withdrew = false;
        }
        highestBidderAddr = msg.sender;

        uint256 usdBalance = payer.ethBalance.getConversionRate();
        uint256 timeLeft = (usdBalance / _blockUsdBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;
    }

    // todo: the next bidder will be used if the first one runs out of funds
    // todo: implement logic so you can withdraw not all but a part depending on how long your ad was up
    
    function withdrawBid(address receiver) external {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        if (msg.sender == highestBidderAddr) revert HighestBidderCantWithdraw();

        Payer memory payer = addressToPayer[msg.sender];
        if (payer.blockUsdBid == 0) revert NoSuchPayer();
        if (payer.withdrew) revert BidderAlreadyWithdrew();

        addressToPayer[msg.sender].withdrew = true;

        (bool res, ) = receiver.call{ value: payer.ethAmount }(""); // convert to payable?
        if (!res) revert BidWithdrawalFailed();
    }

    function withdraw(address receiver) external onlyOwner {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();

        if (winner.ethBalance > 0) {
            chargeForAdCalc();
        }

        if (address(this).balance < ownerBalanceAvailable) revert AdAuctionBalanceIsTooLow(); // assert ?
        ownerBalanceAvailable = 0;

        (bool res, ) = receiver.call{ value: ownerBalanceAvailable }("");
        if (!res) revert OwnerWithdrawalFailed();
    }

    function chargeForAd() external onlyOwner {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        chargeForAdCalc();
    }

    function chargeForAdCalc() internal onlyOwner {
        if (winner.ethBalance == 0) revert NoFundsToCharge();
        assert(winner.timeLeft == 0, "AdAuction::chargeForAd: Panic. Time left must be zero if eth balance is zero.");

        Payer storage winner = addressToPayer[highestBidderAddr];
        uint256 timeLeft = winner.timeLeft;
        uint256 cutOffTime = endAuctionTime + winner.timeLeft;
        uint256 timeUsed = block.timestamp - endAuctionTime;
        
        if (timeUsed >= timeLeft) {
            winner.ethUsed += winner.ethBalance;
            ownerBalanceAvailable += winner.ethBalance;
            winner.ethBalance = 0;
            winner.timeLeft = 0;
        } else {
            uint256 blocksUsed = timeUsed / 12;
            uint256 paidInUsd = blocksUsed * winner.blockUsdBid;
            uint256 oldUsdBalance = winner.ethBalance.convertEthToUsd();
            uint256 newUsdBalance = oldUsdBalance - paidInUsd;

            winner.timeLeft = timeLeft - timeUsed;

            winner.ethBalance = newUsdBalance.convertUsdToEth();
            uint256 paidInEth = paidInUsd.convertUsdToEth();
            winner.ethUsed += paidInEth;
            ownerBalanceAvailable += paidInEth;
        }
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
    }
}