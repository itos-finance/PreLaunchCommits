// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IWETH } from "../interfaces/IWETH.sol";

contract ArbInit {
    IWETH public WETHContract;
    address[] public usableTokens;
    address public oracle;
    mapping(address => bool) public stables;

    function init() public {
        WETHContract = IWETH()
    }
}

contract ArbInitTest {
    IWETH public WETHContract;
    address[] public usableTokens;
    address public oracle;
    mapping(address => bool) public stables;

    function init() public {
        WETHContract = IWETH()
    }
}
