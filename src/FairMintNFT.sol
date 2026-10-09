// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
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
    uint256 public immutable MINT_PRICE_PUBLIC;
    uint256 public immutable MINT_PRICE_ALLOWLIST;
    uint256 public immutable MAX_PER_WALLET_ALLOWLIST;
    uint256 public immutable MAX_PER_WALLET_PUBLIC;
    uint256 private nextTokenId = 1;
    bytes32 public merkleRoot;

    MintStage public mintStage;
    mapping(address => uint256) public allowlistMinted;
    mapping(address => uint256) public publicMinted;

    event MintStageChanged(uint8 newStage);
    event Withdrawn(address indexed to, uint256 amount);
    event MerkleRootUpdated(bytes32 newRoot);

    error MaxSupplyExceeded();
    error QuantityZero();
    error RecipientNotAccept();
    error BalanceContractZero();
    error MintNotPublicStage(MintStage currentStage);
    error MintNotAllowlistStage(MintStage currentStage);
    error MintStageCannotBeChanged(MintStage currentStage, MintStage newStage);
    error ValueNotEqualTotalMintPrice(uint256 currentValue, uint256 totalMintPrice);
    error WalletLimitExceeded(uint256 quantity, uint256 currentQuantity, uint256 maxPerWallet);
    error NotInAllowlist(address account);
    error MerkleRootLocked(MintStage currentStage);
    error MerkleRootNotSet();

    constructor(
        address initialOwner,
        uint256 _maxSupply,
        uint256 _mintPricePublic,
        uint256 _mintPriceAllowlist,
        uint256 _maxPerWalletAllowlist,
        uint256 _maxPerWalletPublic
    ) ERC721("FAIR", "FAIR") Ownable(initialOwner) {
        MAX_SUPPLY = _maxSupply;
        MINT_PRICE_PUBLIC = _mintPricePublic;
        MINT_PRICE_ALLOWLIST = _mintPriceAllowlist;
        MAX_PER_WALLET_ALLOWLIST = _maxPerWalletAllowlist;
        MAX_PER_WALLET_PUBLIC = _maxPerWalletPublic;
    }

    function mint(uint256 quantity) external payable {
        require(mintStage == MintStage.Public, MintNotPublicStage(mintStage));

        _processMint(publicMinted, MINT_PRICE_PUBLIC, quantity, MAX_PER_WALLET_PUBLIC);
    }

    function allowlistMint(uint256 quantity, bytes32[] calldata proof) external payable {
        require(mintStage == MintStage.Allowlist, MintNotAllowlistStage(mintStage));
        require(
            MerkleProof.verify(proof, merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(msg.sender))))),
            NotInAllowlist(msg.sender)
        );

        _processMint(allowlistMinted, MINT_PRICE_ALLOWLIST, quantity, MAX_PER_WALLET_ALLOWLIST);
    }

    function _processMint(
        mapping(address => uint256) storage counter,
        uint256 mintPrice,
        uint256 quantity,
        uint256 maxPerWallet
    ) private {
        require(quantity > 0, QuantityZero());
        require(quantity <= MAX_SUPPLY - totalSupply(), MaxSupplyExceeded());
        uint256 totalMintPrice = quantity * mintPrice;
        require(msg.value == totalMintPrice, ValueNotEqualTotalMintPrice(msg.value, totalMintPrice));
        uint256 currentQuantity = counter[msg.sender];
        require(
            currentQuantity + quantity <= maxPerWallet, WalletLimitExceeded(quantity, currentQuantity, maxPerWallet)
        );
        uint256 tempTokenId = nextTokenId;
        nextTokenId += quantity;
        counter[msg.sender] = currentQuantity + quantity;

        for (uint256 index = 0; index < quantity; index++) {
            _safeMint(msg.sender, tempTokenId++);
        }
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        require(mintStage == MintStage.NotStarted, MerkleRootLocked(mintStage));
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function totalSupply() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function changeMintStage(MintStage newStage) external onlyOwner {
        require(
            (mintStage != MintStage.Ended && newStage == MintStage.Ended) || uint8(mintStage) + 1 == uint8(newStage),
            MintStageCannotBeChanged(mintStage, newStage)
        );
        require(newStage != MintStage.Allowlist || merkleRoot != 0, MerkleRootNotSet());

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
