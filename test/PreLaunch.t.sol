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
import {PreLaunchNFT} from "src/PreNFT.sol";
import {ItosPoints1} from "src/Points.sol";

contract PreLaunchTest is PRBTest, StdCheats {
    PreLaunchLP public pool;
    PreLaunchNFT public minter;
    ItosPoints1 public points;
    MintableERC20 public token0;
    MintableERC20 public token1;
    MintableERC20 public badToken;
    address public weth;

    function setUp() public {
        points = new ItosPoints1();

        weth = address(new FakeWETH());
        address oracle = address(new FakeOracle(weth));
        address[] memory tokens = new address[](2);
        token0 = new MintableERC20("0", "0");
        tokens[0] = address(token0);
        token1 = new MintableERC20("1", "1");
        tokens[1] = address(token1);
        badToken = new MintableERC20("2", "2");

        pool = new PreLaunchLP(weth, tokens, oracle, address(points));
        points.addMinter(address(pool));

        token0.mint(address(this), 10 ether);
        token0.approve(address(pool), 10 ether);
        token1.mint(address(this), 10 ether);
        token1.approve(address(pool), 10 ether);
        badToken.mint(address(this), 10 ether);
        badToken.approve(address(pool), 10 ether);
        vm.deal(address(this), 10_000 ether);

        minter = new PreLaunchNFT(address(points));
    }

    function testLP() public {
        pool.LP(address(1), address(token0), 1 ether);
        assertEq(pool.balanceOf(address(1)), 1 ether, "1");
        assertEq(points.balanceOf(address(1)), 1 ether, "1.1");
        assertEq(points.score(address(1)), 1 ether, "1.2");
        assertAlmostEq(pool.lpValue(address(1)), 1 << 128, 1 << 64, "1.3");

        pool.LP(address(2), address(token1), 1 ether);
        assertEq(pool.balanceOf(address(2)), 1 ether, "2");
        // test WETH
        pool.LP{value: 1 ether / 1000}(address(1), address(0), 0);
        assertAlmostEq(pool.balanceOf(address(1)), 2 ether, 1, "3");
        assertAlmostEq(points.score(address(1)), 2 ether, 1, "3.1");
        // test L2
        bytes memory data = abi.encode(address(1), address(token0), 2 ether);
        pool.l2LP(data);
        assertAlmostEq(pool.balanceOf(address(1)), 4 ether, 1, "4");
        pool.l2LP{value: 6 ether / 1000}(data);
        assertAlmostEq(pool.balanceOf(address(1)), 10 ether, 10, "5");

        pool.LP(address(2), address(token0), 1 ether);
        assertAlmostEq(pool.balanceOf(address(2)), 2 ether, 10, "6");

        assertEq(IWETH(weth).balanceOf(address(pool)), 7 ether / 1000, "7");
        assertEq(token0.balanceOf(address(pool)), 4 ether, "8");
        assertEq(token1.balanceOf(address(pool)), 1 ether, "9");

        vm.expectRevert(PreLaunchLP.InvalidTokenEntry.selector);
        pool.LP(address(2), address(badToken), 1 ether);
    }

    function testNFT() public {
        pool.LP(address(this), address(token0), 1 ether);
        assertEq(points.score(address(this)), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(PreLaunchNFT.InsufficientScore.selector, 1 ether, 0));
        minter.mint(address(this), 1);

        bytes memory data = abi.encode(address(this), address(0), 0);
        pool.l2LP{value: 10 ether}(data);
        uint256 score = points.score(address(this));
        // The price is inexact since 1e18 units gives a really small price.
        assertAlmostEq(score, 10_001 ether, 100);

        vm.expectRevert(abi.encodeWithSelector(PreLaunchNFT.OutOfOrderMint.selector, 0));
        minter.mint(address(this), 0);

        vm.expectRevert(abi.encodeWithSelector(PreLaunchNFT.InvalidChoice.selector, 6));
        minter.mint(address(this), (6 << 128) + 1);

        // Succeeds
        minter.mint(address(this), (5 << 128) + 1);

        // Can't mint again.
        vm.expectRevert(abi.encodeWithSelector(PreLaunchNFT.InsufficientScore.selector, score, 1));
        minter.mint(address(this), (4 << 128) + 1);

        // Mint out a whole category.
        pool.l2LP{value: 2000 ether}(data);
        for (uint8 i = 1; i <= 100; ++i) {
            minter.mint(address(this), i);
        }
        // Now we're at cap.
        vm.expectRevert(abi.encodeWithSelector(PreLaunchNFT.CategoryAtCap.selector, 0));
        minter.mint(address(this), 101);

        // But we can mint a different one
        minter.mint(address(this), (5 << 128) + 2);
        minter.mint(address(this), (4 << 128) + 1);
        minter.mint(address(this), (4 << 128) + 2);
    }

    function testExecuteTransfer() public {
        address transferer = address(new TransferExecutor());
        assertEq(token0.balanceOf(address(1)), 0);

        pool.LP(address(this), address(token0), 1 ether);

        pool.preExecute(abi.encode(transferer));
        skip(5 days);

        pool.execute(abi.encodeWithSelector(TransferExecutor.transfer.selector, address(token0), address(1), 1 ether));
        assertEq(token0.balanceOf(address(1)), 1 ether);
    }
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
    address public eth;

    constructor(address weth) {
        eth = weth;
    }

    function price(address token) external view returns (uint256 priceX128) {
        if (token == eth) {
            return (1000 << 128) / uint256(1e18);
        } else {
            return (1 << 128) / uint256(1e18);
        }
    }
}

contract TransferExecutor {
    function transfer(address token, address recipient, uint256 amount) public {
        ERC20(token).transfer(recipient, amount);
    }
}
