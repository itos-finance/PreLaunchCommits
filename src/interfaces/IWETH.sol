// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IWETH {
    function deposit() public payable;
    function withdraw(uint wad) public;
}
