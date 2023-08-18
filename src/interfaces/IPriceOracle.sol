// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IPriceOracle {
    function price(address tokenAddr) external returns (uint256 priceX128);
}
