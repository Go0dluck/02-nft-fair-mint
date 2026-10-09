// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FairMintNFT} from "../src/FairMintNFT.sol";
import {RejectingReceiver} from "./mocks/RejectingReceiver.sol";
import {MaliciousReceiver} from "./mocks/MaliciousReceiver.sol";
import {console} from "forge-std/console.sol";

contract FairMintNFTTest is Test {
    FairMintNFT fairMintNFT;
    address dev;
    address alice;
    address bob;
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;
    uint256 constant PRICE_PUBLIC = 0.01 ether;
    uint256 constant PRICE_ALLOWLIST = 0.005 ether;
    uint256 constant MAX_PER_WALLET_PUBLIC = 3;
    uint256 constant MAX_PER_WALLET_ALLOWLIST = 2;
    bytes32 newRoot;
    string json;

    function setUp() external {
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(user2, 10 ether);
        fairMintNFT =
            new FairMintNFT(dev, 10, PRICE_PUBLIC, PRICE_ALLOWLIST, MAX_PER_WALLET_ALLOWLIST, MAX_PER_WALLET_PUBLIC);
        json = vm.readFile("merkle/output.json");
        newRoot = vm.parseJsonBytes32(json, ".root");
    }

    function test_CanMintExactlyMaxSupply() public {
        _openPublic();
        _mintAs(user1, 3);
        _mintAs(user2, 3);
        _mintAs(user3, 3);
        _mintAs(user4, 1);
        assertEq(fairMintNFT.totalSupply(), 10);
        assertEq(fairMintNFT.ownerOf(10), user4);
    }

    function test_RevertWhen_ExceedsMaxSupply() public {
        _openPublic();
        _mintAs(user1, 3);
        _mintAs(user2, 3);
        _mintAs(user3, 3);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        _mintAs(user4, 3);
        assertEq(fairMintNFT.totalSupply(), 9);
    }

    function test_RevertWhen_ZeroQuantity() public {
        _openPublic();
        vm.expectRevert(FairMintNFT.QuantityZero.selector);
        vm.prank(alice);
        fairMintNFT.mint{value: 0}(0);
    }

    function test_RevertWhen_MintAfterSoldOut() public {
        _openPublic();
        _mintAs(user1, 3);
        _mintAs(user2, 3);
        _mintAs(user3, 3);
        _mintAs(user4, 1);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        _mintAs(user5, 1);
    }

    function test_CanMint_TwoUsers() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.ownerOf(3), alice);
        vm.prank(bob);
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        assertEq(fairMintNFT.ownerOf(4), bob);
        assertEq(fairMintNFT.balanceOf(bob), 2);
        assertEq(fairMintNFT.totalSupply(), 5);
    }

    function test_ChangeMintStage_EmitsEvent() public {
        vm.startPrank(dev);
        fairMintNFT.setMerkleRoot(newRoot);
        vm.expectEmit(false, false, false, true);
        emit FairMintNFT.MintStageChanged(uint8(FairMintNFT.MintStage.Allowlist));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Allowlist));
        vm.stopPrank();
    }

    function test_FullStageLifecycle() public {
        vm.startPrank(dev);
        _openAllowlist();
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Allowlist));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Public));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Ended));
        vm.stopPrank();
    }

    function test_RevertWhen_NotOwnerChangesStage() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
    }

    function test_RevertWhen_StageGoesBack() public {
        vm.startPrank(dev);
        _openAllowlist();
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.expectRevert(
            abi.encodeWithSelector(
                FairMintNFT.MintStageCannotBeChanged.selector,
                FairMintNFT.MintStage.Public,
                FairMintNFT.MintStage.Allowlist
            )
        );
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        vm.stopPrank();
    }

    function test_RevertWhen_StageSkipped() public {
        vm.prank(dev);
        vm.expectRevert(
            abi.encodeWithSelector(
                FairMintNFT.MintStageCannotBeChanged.selector,
                FairMintNFT.MintStage.NotStarted,
                FairMintNFT.MintStage.Public
            )
        );
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
    }

    function test_CanEndFromAllowlistStage() public {
        vm.startPrank(dev);
        _openAllowlist();
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Allowlist));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Ended));
        vm.stopPrank();
    }

    function test_CanEndFromPublicStage() public {
        _openPublic();
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Ended));
    }

    function test_RevertWhen_AlreadyEnded() public {
        vm.startPrank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.expectRevert(
            abi.encodeWithSelector(
                FairMintNFT.MintStageCannotBeChanged.selector, FairMintNFT.MintStage.Ended, FairMintNFT.MintStage.Ended
            )
        );
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.stopPrank();
    }

    function test_RevertWhen_MintInNotStarted() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.NotStarted)
        );
        fairMintNFT.mint{value: PRICE_PUBLIC * 1}(1);
    }

    function test_RevertWhen_MintInAllowlist() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Allowlist)
        );
        fairMintNFT.mint{value: PRICE_PUBLIC * 1}(1);
    }

    function test_RevertWhen_MintInEnded() public {
        _openPublic();
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint{value: PRICE_PUBLIC * 1}(1);
    }

    function test_EndingStageStopsOngoingSale() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint{value: PRICE_PUBLIC * 4}(4);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
    }

    function test_RevertWhen_Underpaid() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.ValueNotEqualTotalMintPrice.selector, PRICE_PUBLIC * 2, PRICE_PUBLIC * 3)
        );
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(3);
    }

    function test_RevertWhen_Overpaid() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.ValueNotEqualTotalMintPrice.selector, PRICE_PUBLIC * 2, PRICE_PUBLIC)
        );
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(1);
    }

    function test_MintTransfersEthToContract() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        assertEq(address(fairMintNFT).balance, PRICE_PUBLIC * 2);
        assertEq(alice.balance, 10 ether - PRICE_PUBLIC * 2);
    }

    function test_RevertWhen_ExceedsWalletLimitInOneTx() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 4, 0, MAX_PER_WALLET_PUBLIC));
        fairMintNFT.mint{value: PRICE_PUBLIC * 4}(4);
    }

    function test_RevertWhen_ExceedsWalletLimitAcrossTxs() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 2, 2, MAX_PER_WALLET_PUBLIC));
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        vm.stopPrank();
    }

    function test_CanMintUpToWalletLimit() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
    }

    function test_WalletLimitIsPerAddress() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        vm.prank(bob);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
        assertEq(fairMintNFT.publicMinted(bob), 3);
    }

    function test_RevertWhen_MintAgainAfterTransfer() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
        fairMintNFT.transferFrom(alice, bob, 1);
        assertEq(fairMintNFT.balanceOf(alice), 2);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 1, 3, MAX_PER_WALLET_PUBLIC));
        fairMintNFT.mint{value: PRICE_PUBLIC * 1}(1);
        vm.stopPrank();
    }

    function test_WithdrawRevertRecipientNotAccept() public {
        vm.deal(user1, PRICE_PUBLIC * 3);
        RejectingReceiver mock = new RejectingReceiver();
        FairMintNFT fair = new FairMintNFT(address(mock), 10, PRICE_PUBLIC, PRICE_ALLOWLIST, 3, MAX_PER_WALLET_PUBLIC);
        vm.startPrank(address(mock));
        fair.setMerkleRoot(newRoot);
        fair.changeMintStage(FairMintNFT.MintStage.Allowlist);
        fair.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
        vm.prank(user1);
        fair.mint{value: PRICE_PUBLIC * 3}(3);
        vm.prank(address(mock));
        vm.expectRevert(FairMintNFT.RecipientNotAccept.selector);
        fair.withdraw();
        assertEq(address(fair).balance, PRICE_PUBLIC * 3);
    }

    function test_WithdrawNotOwner() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        fairMintNFT.withdraw();
        vm.stopPrank();
    }

    function test_WithdrawBalanceContractZero() public {
        vm.prank(dev);
        vm.expectRevert(FairMintNFT.BalanceContractZero.selector);
        fairMintNFT.withdraw();
    }

    function test_WithdrawSuccess() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 2}(2);
        assertEq(address(fairMintNFT).balance, PRICE_PUBLIC * 2);

        vm.expectEmit(true, false, false, true);
        emit FairMintNFT.Withdrawn(dev, PRICE_PUBLIC * 2);
        vm.prank(dev);
        fairMintNFT.withdraw();

        assertEq(address(fairMintNFT).balance, 0);
        assertEq(dev.balance, PRICE_PUBLIC * 2);
    }

    function test_RevertWhen_ReentrantMintExceedsWalletLimit() public {
        _openPublic();
        MaliciousReceiver maliciousReceiver = new MaliciousReceiver(fairMintNFT);
        vm.deal(address(maliciousReceiver), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 3, 3, MAX_PER_WALLET_PUBLIC));
        maliciousReceiver.attack(MAX_PER_WALLET_PUBLIC);
        assertEq(fairMintNFT.balanceOf(address(maliciousReceiver)), 0);
        assertEq(fairMintNFT.totalSupply(), 0);
        assertEq(fairMintNFT.publicMinted(address(maliciousReceiver)), 0);
    }

    function test_SetMerkleRoot_EmitsEvent() public {
        vm.prank(dev);
        vm.expectEmit(false, false, false, true);
        emit FairMintNFT.MerkleRootUpdated(newRoot);
        fairMintNFT.setMerkleRoot(newRoot);
        assertEq(fairMintNFT.merkleRoot(), newRoot);
    }

    function test_RevertWhen_NotOwnerSetsMerkleRoot() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        fairMintNFT.setMerkleRoot(newRoot);
    }

    function test_RevertWhen_SetMerkleRootAfterStart() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MerkleRootLocked.selector, FairMintNFT.MintStage.Allowlist));
        fairMintNFT.setMerkleRoot(newRoot);
        vm.stopPrank();
    }

    function test_RevertWhen_OpenAllowlistWithoutRoot() public {
        vm.prank(dev);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MerkleRootNotSet.selector));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
    }

    function test_CanEndWithoutRoot() public {
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        assertEq(fairMintNFT.merkleRoot(), 0);
    }

    function test_AllowlistMint_ValidProof() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
        assertEq(fairMintNFT.balanceOf(alice), 2);
        assertEq(fairMintNFT.allowlistMinted(alice), 2);
        assertEq(fairMintNFT.publicMinted(alice), 0);
    }

    function test_RevertWhen_NotInAllowlist() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.NotInAllowlist.selector, user2));
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
    }

    function test_RevertWhen_WrongProof() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.NotInAllowlist.selector, alice));
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(bob));
    }

    function test_RevertWhen_EmptyProof() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.NotInAllowlist.selector, address(alice)));
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, new bytes32[](0));
    }

    function test_RevertWhen_ExceedsAllowlistLimitInOneTx() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 3, 0, MAX_PER_WALLET_ALLOWLIST)
        );
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 3}(3, _proofOf(alice));
    }

    function test_RevertWhen_ExceedsAllowlistLimitAcrossTxs() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.startPrank(alice);
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 1}(1, _proofOf(alice));
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.WalletLimitExceeded.selector, 2, 1, MAX_PER_WALLET_ALLOWLIST)
        );
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
        vm.stopPrank();
    }

    function test_RevertWhen_AllowlistMintInNotStarted() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotAllowlistStage.selector, FairMintNFT.MintStage.NotStarted)
        );
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
    }

    function test_RevertWhen_AllowlistMintInPublic() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotAllowlistStage.selector, FairMintNFT.MintStage.Public)
        );
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
    }

    function test_AllowlistMint_PaysDiscountPrice() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
        assertEq(address(fairMintNFT).balance, PRICE_ALLOWLIST * 2);
    }

    function test_RevertWhen_AllowlistPaysPublicPrice() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                FairMintNFT.ValueNotEqualTotalMintPrice.selector, PRICE_PUBLIC * 2, PRICE_ALLOWLIST * 2
            )
        );
        fairMintNFT.allowlistMint{value: PRICE_PUBLIC * 2}(2, _proofOf(alice));
    }

    function test_AllowlistAndPublicLimitsAreSeparate() public {
        vm.startPrank(dev);
        _openAllowlist();
        vm.stopPrank();
        vm.prank(alice);
        fairMintNFT.allowlistMint{value: PRICE_ALLOWLIST * 2}(2, _proofOf(alice));
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE_PUBLIC * 3}(3);
        assertEq(fairMintNFT.totalSupply(), 5);
        assertEq(fairMintNFT.balanceOf(alice), 5);
        assertEq(fairMintNFT.allowlistMinted(alice), 2);
        assertEq(fairMintNFT.publicMinted(alice), 3);
    }

    function test_RevertWhen_HugeQuantityOnEmptyContract() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(type(uint256).max);
    }

    function test_RevertWhen_HugeQuantityAfterFirstMint() public {
        _openPublic();
        _mintAs(alice, 1);
        vm.prank(bob);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(type(uint256).max);
    }

    function _openAllowlist() internal {
        fairMintNFT.setMerkleRoot(newRoot);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
    }

    function _openPublic() internal {
        vm.startPrank(dev);
        _openAllowlist();
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
    }

    function _mintAs(address user, uint256 quantity) internal {
        vm.deal(user, PRICE_PUBLIC * quantity);
        vm.prank(user);
        fairMintNFT.mint{value: PRICE_PUBLIC * quantity}(quantity);
    }

    function _proofOf(address user) internal returns (bytes32[] memory) {
        return vm.parseJsonBytes32Array(json, string.concat(".proofs.", vm.toString(user)));
    }
}
