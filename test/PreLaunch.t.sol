// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "prb-test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";
import {MintableERC20} from "./ERC20.u.sol";
import {PreLaunchLP} from "src/PreLaunch.sol";

contract PreLaunchTest is PRBTest, StdCheats {
    PreLaunchLP public pool;
    MintableERC20 public token0;
    MintableERC20 public token1;

    function setUp() public {
        address weth = address(new FakeWETH());
        address oracle = address(new FakeOracle());
        address init = address(new Initializer());
        address[] memory tokens = new address[](2);
        token0 = new MintableERC20("0", "0");
        tokens[0] = address(token0);
        token1 = new MintableERC20("1", "1");
        tokens[1] = address(token1);

        bytes memory args = abi.encodeWithSelector(Initializer.init.selector, weth, tokens, oracle);
        pool = new PreLaunchLP(init, args);

        token0.mint(address(this), 10 ether);
        token0.approve(address(pool), 10 ether);
        token1.mint(address(this), 10 ether);
        token1.approve(address(pool), 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function testLP() public {
        pool.LP(address(1), address(token0), 1 ether);
    }

    function testWETH() public {}

    function testNFT() public {}

    function testExecuteTransfer() public {}
}

contract FakeWETH is ERC20 {
    constructor() ERC20("WETH", "WETH") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        require(payable(msg.sender).send(wad), "send failed");
    }
}

contract FakeOracle {
    function price(address) external pure returns (uint256 priceX128) {
        return 1 << 128;
    }
}

contract Initializer {
    // slots written to on the initialized contract.
    IWETH public WETHContract;
    address[] public usableTokens;
    IPriceOracle public oracle;

    function init(address wethAddress, address[] memory tokens, address priceOracle) public {
        WETHContract = IWETH(wethAddress);
        oracle = IPriceOracle(priceOracle);
        for (uint16 i = 0; i < tokens.length; ++i) {
            console2.log("pushing", tokens[i]);
            usableTokens.push(tokens[i]);
        }
        console2.log("length", usableTokens.length);
    }
}
