// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

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

// A contract for recording prelaunch LP commits
/// While this contract gives the Itos total flexibility in using this liquidity, there is real legal
/// recourse for misuse of funds, the founders are doxxed, none of our employees are anon, and this is
/// owned and managed by a multi-sig.
contract PreLaunchLP is IPreLaunchLP, ERC20 {
    error InitializationError(address init, bytes data);
    error InvalidTokenEntry();
    error PrematureExecution();
    error PrecommitOwnerMismatch();
    error ExecutionError(address executor, bytes args);
    /// Somehow someones committed more liquidity than we can handle.
    error OverCommitment();

    /* Needs Initialization from init contract */
    /* The same exact storage variables are at the same slots in the
       delegate initializer contract */
    IWETH public WETHContract;
    address[] public usableTokens;
    IPriceOracle public oracle;

    /* No init */
    uint256 public outstandingShares;
    mapping(address => uint256) public lpValue;

    /// The time needed for any execute to take effect.
    uint256 public constant DELAY = 5 days;

    constructor(address init_, bytes memory data) ERC20("ItosPreLP", "IpLP") {
        AdminLib.initOwner(msg.sender);

        ContractLib.assertContract(init_);
        (bool success, bytes memory err) = init_.delegatecall(data);
        if (!success) {
            if (err.length > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(err)
                    revert(add(32, err), returndata_size)
                }
            } else {
                revert InitializationError(init_, data);
            }
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
        uint256 totalValue;
        for (uint8 i = 0; i < usableTokens.length; ++i) {
            address current = usableTokens[i];
            uint256 priceX128;
            priceX128 = oracle.price(current);
            uint256 balance = IERC20Minimal(current).balanceOf(address(this));
            if (current == token) {
                tokenPriceX128 = priceX128;
                // Don't include our transfered amounts in the new balance.
                (uint256 bot, uint256 top) = X128.mul512RoundUp(priceX128, balance - amount);
                if (top > 0) {
                    revert OverCommitment();
                }
                totalValue += bot;
            } else {
                (uint256 bot, uint256 top) = X128.mul512RoundUp(priceX128, balance);
                if (top > 0) {
                    revert OverCommitment();
                }
                totalValue += bot;
            }
        }

        // If we didn't find the token address within our list of usable tokens.
        if (tokenPriceX128 == 0) {
            revert InvalidTokenEntry();
        }

        uint256 value = X128.mul256RoundUp(amount, tokenPriceX128);
        lpValue[recipient] += value;
        uint256 shares = FullMath.mulDiv(outstandingShares, value, totalValue);
        outstandingShares += shares;

        _mint(recipient, shares);
    }

    /// We prerecord the contract we'll want to delegate call into for transparency.
    /// If we act misappropriately, users and investors can initiate recourse well before we take action.
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
