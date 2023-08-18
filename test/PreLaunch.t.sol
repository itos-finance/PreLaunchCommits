// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";


contract PreLaunchTest is PRBTest, StdCheats {
    PreLaunchLP pool;

    function setUp() public {
        new PreLaunchLP()
    }

    function testLP() public {

    }

    function testWETH() public {

    }

    function testNFT() public {

    }

    function testExecuteTransfer() public {

    }
}

contract FakeWETH is ERC20 {
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint wad) external {
        _burn(msg.sender, wad);
        msg.sender.send(wad);
    }
}

contract FakeOracle is ERC20 {
    function price(address token) external returns (uint256 priceX128) {
        return 1 << 128;
    }
}

contract Initializer {
    IWETH public WETHContract;
    address[] public usableTokens;
    IPriceOracle public oracle;

    constructor(address WETH, )

    function init() public {

    }
}