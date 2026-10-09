// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {FairMintNFT} from "../../src/FairMintNFT.sol";

contract MaliciousReceiver is IERC721Receiver {
    FairMintNFT public immutable fairMintNFT;
    uint256 public quantityPerMint;
    bool private reentered;

    constructor(FairMintNFT _fairMintNFT) {
        fairMintNFT = _fairMintNFT;
    }

    function attack(uint256 quantity) external {
        quantityPerMint = quantity;
        _mint();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        // Повторный вход только один раз, иначе рекурсия до исчерпания газа
        if (!reentered) {
            reentered = true;
            _mint();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function _mint() private {
        fairMintNFT.mint{value: fairMintNFT.MINT_PRICE_PUBLIC() * quantityPerMint}(quantityPerMint);
    }
}
