// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract PreLaunchTest is PRBTest, StdCheats {
    PreLaunchLP pool;

    function setUp() public {
        new PreLaunchLP()
    }

    function testLP() public {

    }
}
