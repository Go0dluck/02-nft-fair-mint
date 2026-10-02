// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FairMintNFT is ERC721, Ownable2Step {
    uint256 public immutable MAX_SUPPLY;
    uint256 private nextTokenId = 1;

    error MaxSupplyExceeded();
    error QuantityZero();

    constructor(address initialOwner, uint256 _maxSupply) ERC721("FAIR", "FAIR") Ownable(initialOwner) {
        MAX_SUPPLY = _maxSupply;
    }

    function mint(uint256 quantity) external {
        require(quantity > 0, QuantityZero());
        require(totalSupply() + quantity <= MAX_SUPPLY, MaxSupplyExceeded());

        uint256 tempTokenId = nextTokenId;
        nextTokenId += quantity;

        for (uint256 index = 0; index < quantity; index++) {
            _mint(msg.sender, tempTokenId++);
        }
    }

    function totalSupply() public view returns (uint256) {
        return nextTokenId - 1;
    }
}
