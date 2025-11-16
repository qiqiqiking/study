// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@chainlink/contracts/src/v0.8/data-feeds/interfaces/IDecimalAggregator.sol";

library PriceConverter {
    // ETH/USD Feed (Mainnet): 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    // USDC/USD Feed (Mainnet): 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6

    function getLatestPrice(address feed) internal view returns (int256) {
        IDecimalAggregator priceFeed = IDecimalAggregator(feed); 
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return price;
    }

    // 将 amount（单位：wei 或 token 最小单位）转换为 USD（单位：1e8）
    function convertToUsd(
        uint256 amount,
        uint8 decimals,
        address feed
    ) internal view returns (uint256) {
        int256 price = getLatestPrice(feed); // price in 1e8
        // amount * price / (10^decimals)
        return (amount * uint256(price)) / (10 ** decimals);
    }
}