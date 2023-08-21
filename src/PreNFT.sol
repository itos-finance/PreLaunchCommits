// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IItosPoints1} from "./interfaces/IPoints.sol";

contract PreLaunchNFT is ERC721 {
    error InsufficientScore(uint256 score, uint16 previousMints);
    error InvalidChoice(uint8 choice);
    error CategoryAtCap(uint8 choice);
    error OutOfOrderMint(uint16 currentCount);

    uint256 public constant MIN_MINT_SCORE = 10_000 ether;
    uint8 public constant CATEGORY_MAX = 100;
    uint8 public constant NUM_CHOICES = 6;

    mapping(address => uint16) public mintCount;
    mapping(uint8 => uint16) public categoryCount;

    IItosPoints1 public points;

    constructor(address _points) ERC721("ItosPreNFT", "IpNFT") {
        points = IItosPoints1(_points);
    }

    /// @notice For every MIN_MINT_SCORE earned by a user, allow them to mint one NFT.
    /// @dev There are {NUM_CHOICES} categories of NFTs to choose from.
    /// @param tokenId The top 128 bits indicates the choice, and the bottom 128 bits
    /// must increment up from the previous mint. I.e. the first mint for category 2 would be
    /// (2 << 128) + 1.
    function mint(address to, uint256 tokenId) external {
        uint8 choice = uint8(tokenId >> 128);
        if (choice >= NUM_CHOICES) {
            revert InvalidChoice(choice);
        }

        uint256 score = points.score(msg.sender);
        uint16 mints = mintCount[msg.sender];
        if (score < MIN_MINT_SCORE * (mints + 1)) {
            revert InsufficientScore(score, mints);
        }

        uint256 current = tokenId & type(uint128).max;
        if (current > CATEGORY_MAX) {
            revert CategoryAtCap(choice);
        }
        if (current != categoryCount[choice] + 1) {
            revert OutOfOrderMint(categoryCount[choice]);
        }

        categoryCount[choice]++;
        mintCount[msg.sender]++;
        _mint(to, tokenId);
    }
}
