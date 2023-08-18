// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IPreLaunchLP {
    /// Query the USD value of committed by an individual. Value is determined at the time of commit.
    function lpValue(address lper) external returns (uint256 value);

    /// Commit liquidity while saving some gas by reducing calldata size.
    function l2LP(bytes calldata data) external payable;

    /// Commits liquidity to this contract for the Itos team to use in bootstrapping the protocol.
    /// @param recipient Who receives
    /// @param token Which token is being provided.
    /// @param amount How much of the token to supply.
    function LP(address recipient, address token, uint128 amount) external payable;
}
