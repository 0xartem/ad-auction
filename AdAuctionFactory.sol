// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { AdAuction } from './AdAuction.sol';

contract AdAuctoinFactory {

    AdAuction[] public adAuctionArray;

    function createAdAuction() public  {
        AdAuction adAuction = new AdAuction(0, 0);
        adAuctionArray.push(adAuction);
    }

}