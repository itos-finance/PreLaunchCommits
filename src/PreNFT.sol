// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IPreLaunchLP} from "./interfaces/IPreLaunchLP.sol";

contract PreLaunchNFT is ERC721 {
    error InsufficientLPValue(uint256 lpValue, uint16 previousMints);
    error InvalidChoice(uint8 choice);
    error CategoryAtCap(uint8 choice);
    error OutOfOrderMint(uint16 currentCount);

    uint256 public constant MIN_LP_VALUE = 10_000;
    uint256 public constant CATEGORY_MAX = 100;
    uint8 public constant NUM_CHOICES = 6;

    mapping(address => uint16) public mintCount;
    mapping(uint8 => uint16) public categoryCount;

    IPreLaunchLP public preLauncher;

    constructor(address preLP) ERC721("ItosPreNFT", "IpNFT") {
        preLauncher = IPreLaunchLP(preLP);
    }

    /// For every MIN_LP_VALUE the user as committed, they can mint an NFT.
    /// There are {NUM_CHOICES} categories of NFTs to choose from.
    /// @param tokenId The top 128 bits indicates the choice, and the bottom 128 bits
    /// must increment up from the previous mint. I.e. the first mint for category 2 would be
    /// (2 << 128) + 1.
    function mint(address to, uint256 tokenId) external {
        uint8 choice = uint8(tokenID >> 128);
        if (choice >= NUM_CHOICES) {
            revert InvalidChoice(choice);
        }

        uint256 value = preLauncher.lpValue(msg.sender);
        uint16 mints = mintCount[msg.sender];
        if (value - MIN_LP_VALUE * mints < MIN_LP_VALUE) {
            revert InsufficientLPValue(value, mints);
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
