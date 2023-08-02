// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { ERC1155 } from "openzeppelin-contracts/token/ERC1155.sol";

contract PreLaunch is ERC1155 {
    address WETHContract;
    address oracles;

    constructor(address init_, string calldata uri_) ERC1155(uri_) {

    }

    function investAndLP() public payable {

    }

    function invest() {

    }

    function LP() {
    }

    // Same as just LPing
    function mint(address to, uint256 amount, bytes memory data) {

    }



}
