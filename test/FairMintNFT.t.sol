// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FairMintNFT} from "../src/FairMintNFT.sol";
import {RejectingReceiver} from "./mocks/RejectingReceiver.sol";

contract FairMintNFTTest is Test {
    FairMintNFT fairMintNFT;
    address dev;
    address alice;
    address bob;
    uint256 constant PRICE = 0.01 ether;
    uint256 constant MAX_PER_WALLET = 3;

    function setUp() external {
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        fairMintNFT = new FairMintNFT(dev, 10, PRICE, 3, MAX_PER_WALLET);
    }

    function test_CanMintExactlyMaxSupply() public {
        _openPublic();
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        _mintAs(user1, 3);
        _mintAs(user2, 3);
        _mintAs(user3, 3);
        _mintAs(user4, 1);
        assertEq(fairMintNFT.totalSupply(), 10);
        assertEq(fairMintNFT.ownerOf(10), user4);
    }

    function test_RevertWhen_ExceedsMaxSupply() public {
        _openPublic();
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
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
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        address user5 = makeAddr("user5");
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
        fairMintNFT.mint{value: PRICE * 3}(3);
        assertEq(fairMintNFT.ownerOf(3), alice);
        vm.prank(bob);
        fairMintNFT.mint{value: PRICE * 2}(2);
        assertEq(fairMintNFT.ownerOf(4), bob);
        assertEq(fairMintNFT.balanceOf(bob), 2);
        assertEq(fairMintNFT.totalSupply(), 5);
    }

    function test_ChangeMintStage_EmitsEvent() public {
        vm.startPrank(dev);
        vm.expectEmit(false, false, false, true);
        emit FairMintNFT.MintStageChanged(uint8(FairMintNFT.MintStage.Allowlist));
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        assertEq(uint8(fairMintNFT.mintStage()), uint8(FairMintNFT.MintStage.Allowlist));
        vm.stopPrank();
    }

    function test_FullStageLifecycle() public {
        vm.startPrank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
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
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
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
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
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
        fairMintNFT.mint{value: PRICE * 1}(1);
    }

    function test_RevertWhen_MintInAllowlist() public {
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Allowlist)
        );
        fairMintNFT.mint{value: PRICE * 1}(1);
    }

    function test_RevertWhen_MintInEnded() public {
        _openPublic();
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint{value: PRICE * 1}(1);
    }

    function test_EndingStageStopsOngoingSale() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE * 3}(3);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint{value: PRICE * 4}(4);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
    }

    function test_RevertWhen_Underpaid() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.ValueNotEqualTotalMintPrice.selector, PRICE * 2, PRICE * 3));
        fairMintNFT.mint{value: PRICE * 2}(3);
    }

    function test_RevertWhen_Overpaid() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.ValueNotEqualTotalMintPrice.selector, PRICE * 2, PRICE));
        fairMintNFT.mint{value: PRICE * 2}(1);
    }

    function test_MintTransfersEthToContract() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE * 2}(2);
        assertEq(address(fairMintNFT).balance, PRICE * 2);
        assertEq(alice.balance, 10 ether - PRICE * 2);
    }

    function test_RevertWhen_ExceedsWalletLimitInOneTx() public {
        _openPublic();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MaxPerWalletPublicLimitExceeded.selector, 4, 0, MAX_PER_WALLET)
        );
        fairMintNFT.mint{value: PRICE * 4}(4);
    }

    function test_RevertWhen_ExceedsWalletLimitAcrossTxs() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE * 2}(2);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MaxPerWalletPublicLimitExceeded.selector, 2, 2, MAX_PER_WALLET)
        );
        fairMintNFT.mint{value: PRICE * 2}(2);
        vm.stopPrank();
    }

    function test_CanMintUpToWalletLimit() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
    }

    function test_WalletLimitIsPerAddress() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE * 3}(3);
        vm.prank(bob);
        fairMintNFT.mint{value: PRICE * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
        assertEq(fairMintNFT.publicMinted(bob), 3);
    }

    function test_RevertWhen_MintAgainAfterTransfer() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE * 3}(3);
        assertEq(fairMintNFT.publicMinted(alice), 3);
        fairMintNFT.transferFrom(alice, bob, 1);
        assertEq(fairMintNFT.balanceOf(alice), 2);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MaxPerWalletPublicLimitExceeded.selector, 1, 3, MAX_PER_WALLET)
        );
        fairMintNFT.mint{value: PRICE * 1}(1);
        vm.stopPrank();
    }

    function test_WithdrawRevertRecipientNotAccept() public {
        address user1 = makeAddr("user1");
        vm.deal(user1, PRICE * 3);
        RejectingReceiver mock = new RejectingReceiver();
        FairMintNFT fair = new FairMintNFT(address(mock), 10, PRICE, 3, MAX_PER_WALLET);
        vm.startPrank(address(mock));
        fair.changeMintStage(FairMintNFT.MintStage.Allowlist);
        fair.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
        vm.prank(user1);
        fair.mint{value: PRICE * 3}(3);
        vm.prank(address(mock));
        vm.expectRevert(FairMintNFT.RecipientNotAccept.selector);
        fair.withdraw();
        assertEq(address(fair).balance, PRICE * 3);
    }

    function test_WithdrawNotOwner() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE * 2}(2);
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
        fairMintNFT.mint{value: PRICE * 2}(2);
        assertEq(address(fairMintNFT).balance, PRICE * 2);

        vm.expectEmit(true, false, false, true);
        emit FairMintNFT.Withdrawn(dev, PRICE * 2);
        vm.prank(dev);
        fairMintNFT.withdraw();

        assertEq(address(fairMintNFT).balance, 0);
        assertEq(dev.balance, PRICE * 2);
    }

    function _openPublic() internal {
        vm.startPrank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
    }

    function _mintAs(address user, uint256 quantity) internal {
        vm.deal(user, PRICE * quantity);
        vm.prank(user);
        fairMintNFT.mint{value: PRICE * quantity}(quantity);
    }
}
