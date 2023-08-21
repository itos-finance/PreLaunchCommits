// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AdminLib} from "Util/Admin.sol";
import {IItosPoints1} from "src/interfaces/IPoints.sol";

contract ItosPoints1 is IItosPoints1, ERC20 {
    address public owner;
    mapping(address => bool) public minters;
    mapping(address => uint256) public score;

    constructor() ERC20("Itos Season 1 Points", "ItosPts1") {
        owner = msg.sender;
    }

    function addMinter(address newMinter) external {
        require(msg.sender == owner, "OWN");
        minters[newMinter] = true;
    }

    function removeMinter(address oldMinter) external {
        require(msg.sender == owner, "OLD");
        delete minters[oldMinter];
    }

    function mint(address recipient, uint256 amount) external {
        require(minters[msg.sender], "BAD");
        score[recipient] += amount;
        _mint(recipient, amount);
    }
}
