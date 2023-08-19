// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IWETH} from "../interfaces/IWETH.sol";

contract ArbInit {
    IWETH public WETHContract;
    address[] public usableTokens;
    address public oracle;

    function init() public {
        // WETHContract = IWETH();
    }
}

contract ArbInitTest {
    IWETH public WETHContract;
    address[] public usableTokens;
    address public oracle;

    function init() public {
        // WETHContract = IWETH();
    }
}
