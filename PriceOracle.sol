// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceOracle {

    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e); // Goerli
        uint8 decimals = priceFeed.decimals();
        require(decimals > 0, "AdAuction::getPrice: decimals in the price oracle are wrong");
        
        (,int256 usdPrice,,,) = priceFeed.latestRoundData();
        return uint256(usdPrice) * 1 ** (18 - decimals);
    }

    function getConversionRate(uint256 eth) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e); // Goerli
        uint256 ethPrice = getPrice();
        uint256 ethInUsd = (ethPrice * usdPrice) / 1e18;
        return ethInUsd;
    }
}