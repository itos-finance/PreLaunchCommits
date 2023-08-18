// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IPriceOracle {
    function price(address tokenAddr) external returns (uint256 priceX128);
}
