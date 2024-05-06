// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

// CHAINLINK
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FundECtools {

    // PriceFeeds
    AggregatorV3Interface internal dataFeedMATICUSD;
    AggregatorV3Interface internal dataFeedUSDCUSD;
    AggregatorV3Interface internal dataFeedUSDTUSD;
    AggregatorV3Interface internal dataFeedDAIUSD;

    constructor() {

        dataFeedMATICUSD = AggregatorV3Interface(
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        );

        dataFeedUSDCUSD = AggregatorV3Interface(
            0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
        );

        dataFeedUSDTUSD = AggregatorV3Interface(
            0x0A6513e40db6EB1b165753AD52E80663aeA50545
        );

        dataFeedDAIUSD = AggregatorV3Interface(
            0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D
        );

    }

    // PRICE FEEDS
    function getChainlinkDataFeedMATICLatestAnswer() public view returns (int256 ) {
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
        ) = dataFeedMATICUSD.latestRoundData();
        return answer;
    }

    function getChainlinkDataFeedUSDCLatestAnswer() public view virtual returns (int256 ) {
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
        ) = dataFeedUSDCUSD.latestRoundData();
        return answer;
    }

    function getChainlinkDataFeedUSDTLatestAnswer() public view virtual returns (int256 ) {
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
        ) = dataFeedUSDTUSD.latestRoundData();
        return answer;
    }

    function getChainlinkDataFeedDAILatestAnswer() public view returns (int256 ) {
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
        ) = dataFeedDAIUSD.latestRoundData();
        return answer;
    }


}

