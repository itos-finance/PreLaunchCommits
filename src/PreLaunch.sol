// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {console2} from "forge-std/console2.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {ContractLib} from "Util/Contract.sol";
import {IERC20Minimal} from "../lib/Commons/lib/ERC/interfaces/IERC20Minimal.sol";
import {AdminLib} from "Util/Admin.sol";
import {X128} from "Math/Ops.sol";
import {FullMath} from "Math/FullMath.sol";
import {Timed, TimedEntry} from "Util/Timed.sol";
import {IPreLaunchLP} from "./interfaces/IPreLaunchLP.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IItosPoints1} from "./interfaces/IPoints.sol";

// A contract for recording prelaunch LP commits
/// While this contract gives the Itos total flexibility in using this liquidity, there is real legal
/// recourse for misuse of funds, the founders are doxxed, none of our employees are anon, and this is
/// owned and managed by a multi-sig.
contract PreLaunchLP is IPreLaunchLP, ERC20 {
    error InvalidTokenEntry();
    error PrematureExecution();
    error PrecommitOwnerMismatch();
    error ExecutionError(address executor, bytes args);

    /* Needs Initialization from init contract */
    /* The same exact storage variables are at the same slots in the
       delegate initializer contract */
    IWETH public WETHContract;
    address[] public usableTokens;
    IPriceOracle public oracle;
    IItosPoints1 public points;

    /* No init */
    uint256 public outstandingShares;
    mapping(address => uint256) public lpValue;

    /// The time needed for any execute to take effect.
    uint256 public constant DELAY = 5 days;

    constructor(address _weth, address[] memory _tokens, address _oracle, address _points)
        ERC20("ItosPreLP", "ItosLP")
    {
        AdminLib.initOwner(msg.sender);

        WETHContract = IWETH(_weth);
        oracle = IPriceOracle(_oracle);
        points = IItosPoints1(_points);

        bool includedWeth = false;

        for (uint16 i = 0; i < _tokens.length; ++i) {
            usableTokens.push(_tokens[i]);
            includedWeth = includedWeth || (_tokens[i] == _weth);
        }

        // Just make sure Weth is in the list.
        if (!includedWeth) {
            usableTokens.push(_weth);
        }
    }

    /// @inheritdoc IPreLaunchLP
    function l2LP(bytes calldata data) external payable {
        (address recipient, address token, uint128 amount) = abi.decode(data, (address, address, uint128));
        LP(recipient, token, amount);
    }

    /// @inheritdoc IPreLaunchLP
    function LP(address recipient, address token, uint128 amount) public payable override {
        if (msg.value > 0) {
            // If the token being provided is ETH, we already have it
            // and can convert to WETH.
            (token, amount) = handlePaidETH();
        } else {
            // Otherwise, we need to get the tokens assuming they've given us
            // allowances.
            IERC20Minimal(token).transferFrom(msg.sender, address(this), amount);
        }

        uint256 tokenPriceX128;
        uint256 totalValueX128;
        for (uint8 i = 0; i < usableTokens.length; ++i) {
            address current = usableTokens[i];
            uint256 priceX128;
            priceX128 = oracle.price(current);
            uint256 balance = IERC20Minimal(current).balanceOf(address(this));
            if (current == token) {
                tokenPriceX128 = priceX128;
                totalValueX128 += priceX128 * (balance - amount);
            } else {
                totalValueX128 += priceX128 * balance;
            }
        }

        // If we didn't find the token address within our list of usable tokens.
        if (tokenPriceX128 == 0) {
            revert InvalidTokenEntry();
        }

        uint256 valueX128 = amount * tokenPriceX128;
        lpValue[recipient] += valueX128;

        uint256 shares;
        if (totalValueX128 == 0) {
            // This is the first time anyone has LPed.
            // Our ERC20 has 18 decimals. Each share is roughly worth a dollar.
            shares = X128.mul256RoundUp(uint128(1e18), valueX128);
        } else {
            shares = FullMath.mulDiv(outstandingShares, valueX128, totalValueX128);
        }

        outstandingShares += shares;
        _mint(recipient, shares);
        // We also give the user points.
        points.mint(recipient, shares);
    }

    /// We prerecord the contract we'll want to delegate call into for transparency.
    /// If we act misappropriately, users and investors can initiate recourse well before we take action.
    /// Can also be used to veto by giving the null address.
    function preExecute(bytes calldata executorAddress) external {
        AdminLib.validateOwner();
        Timed.precommit(0, executorAddress);
    }

    /// The function which gives the team flexibility in using these funds.
    /// Again, there is legal recourse for misappropriation.
    function execute(bytes calldata args) external {
        AdminLib.validateOwner();
        TimedEntry memory e = Timed.fetchAndDelete(0);
        if ((uint64(block.timestamp) - e.timestamp) < DELAY) {
            revert PrematureExecution();
        }
        // Should just be owner, but if owner changes they can't use the old precommit.
        if (e.submitter != msg.sender) {
            revert PrecommitOwnerMismatch();
        }

        address executor = abi.decode(e.entry, (address));
        ContractLib.assertContract(executor);
        (bool success, bytes memory err) = executor.delegatecall(args);
        if (!success) {
            if (err.length > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(err)
                    revert(add(32, err), returndata_size)
                }
            } else {
                revert ExecutionError(executor, args);
            }
        }
    }

    /* Helpers */

    function handlePaidETH() internal returns (address, uint128) {
        WETHContract.deposit{value: msg.value}();
        return (address(WETHContract), uint128(msg.value));
    }
}
