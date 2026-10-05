// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FairMintNFT is ERC721, Ownable2Step {
    enum MintStage {
        NotStarted,
        Allowlist,
        Public,
        Ended
    }

    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MINT_PRICE;
    uint256 public immutable MAX_PER_WALLET_ALLOWLIST;
    uint256 public immutable MAX_PER_WALLET_PUBLIC;
    uint256 private nextTokenId = 1;
    MintStage public mintStage;
    mapping(address => uint256) public allowlistMinted;
    mapping(address => uint256) public publicMinted;

    event MintStageChanged(uint8 newStage);
    event Withdrawn(address indexed to, uint256 amount);

    error MaxSupplyExceeded();
    error QuantityZero();
    error RecipientNotAccept();
    error BalanceContractZero();
    error MintNotPublicStage(MintStage currentStage);
    error MintStageCannotBeChanged(MintStage currentStage, MintStage newStage);
    error ValueNotEqualTotalMintPrice(uint256 currentValue, uint256 totalMintPrice);
    error MaxPerWalletAllowlistLimitExceeded(uint256 quantity, uint256 currentQuantity, uint256 maxPerWalletAllowlist);
    error MaxPerWalletPublicLimitExceeded(uint256 quantity, uint256 currentQuantity, uint256 maxPerWalletPublic);

    constructor(
        address initialOwner,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWalletAllowlist,
        uint256 _maxPerWalletPublic
    ) ERC721("FAIR", "FAIR") Ownable(initialOwner) {
        MAX_SUPPLY = _maxSupply;
        MINT_PRICE = _mintPrice;
        MAX_PER_WALLET_ALLOWLIST = _maxPerWalletAllowlist;
        MAX_PER_WALLET_PUBLIC = _maxPerWalletPublic;
    }

    function mint(uint256 quantity) external payable {
        require(mintStage == MintStage.Public, MintNotPublicStage(mintStage));
        require(quantity > 0, QuantityZero());
        require(totalSupply() + quantity <= MAX_SUPPLY, MaxSupplyExceeded());

        uint256 totalMintPrice = quantity * MINT_PRICE;
        require(msg.value == totalMintPrice, ValueNotEqualTotalMintPrice(msg.value, totalMintPrice));

        uint256 currentQuantity = publicMinted[msg.sender];
        require(
            currentQuantity + quantity <= MAX_PER_WALLET_PUBLIC,
            MaxPerWalletPublicLimitExceeded(quantity, currentQuantity, MAX_PER_WALLET_PUBLIC)
        );
        publicMinted[msg.sender] = currentQuantity + quantity;

        uint256 tempTokenId = nextTokenId;
        nextTokenId += quantity;

        for (uint256 index = 0; index < quantity; index++) {
            _mint(msg.sender, tempTokenId++);
        }
    }

    function totalSupply() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function changeMintStage(MintStage newStage) external onlyOwner {
        require(
            (mintStage != MintStage.Ended && newStage == MintStage.Ended) || uint8(mintStage) + 1 == uint8(newStage),
            MintStageCannotBeChanged(mintStage, newStage)
        );

        mintStage = newStage;
        emit MintStageChanged(uint8(newStage));
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, BalanceContractZero());

        (bool success,) = owner().call{value: balance}("");
        require(success, RecipientNotAccept());
        emit Withdrawn(owner(), balance);
    }
}
