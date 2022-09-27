// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAdAuction {
    function payForAd(string calldata _name, string calldata _imageUrl, string calldata _text) payable external;
    function withdrawBid(address receiver) external;
    function withdraw(address receiver) external 
}