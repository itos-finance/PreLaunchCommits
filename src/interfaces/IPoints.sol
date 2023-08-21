// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IItosPoints1 {
    /// The total points earned by a given address. Not their balance.
    function score(address) external returns (uint256);

    /// Add another approved minter.
    function addMinter(address) external;

    /// Remove an existing minter.
    function removeMinter(address) external;

    /// A pre-approved minter can mint more points to an address.
    function mint(address, uint256) external;
}
