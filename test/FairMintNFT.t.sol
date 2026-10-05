// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FairMintNFT} from "../src/FairMintNFT.sol";

contract FairMintNFTTest is Test {
    FairMintNFT fairMintNFT;
    address dev;
    address alice;
    address bob;
    uint256 constant PRICE = 0.01 ether;

    function setUp() external {
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        fairMintNFT = new FairMintNFT(dev, 10, PRICE);
    }

    function test_CanMintExactlyMaxSupply() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint{value: PRICE * 10}(10);
        assertEq(fairMintNFT.balanceOf(alice), 10);
        assertEq(fairMintNFT.totalSupply(), 10);
        assertEq(fairMintNFT.ownerOf(1), alice);
        assertEq(fairMintNFT.ownerOf(10), alice);
    }

    function test_RevertWhen_ExceedsMaxSupply() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE * 8}(8);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint{value: PRICE * 5}(5);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroQuantity() public {
        _openPublic();
        vm.expectRevert(FairMintNFT.QuantityZero.selector);
        vm.prank(alice);
        fairMintNFT.mint{value: 0}(0);
    }

    function test_RevertWhen_MintAfterSoldOut() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint{value: PRICE * 10}(10);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint{value: PRICE * 1}(1);
        vm.stopPrank();
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

    function _openPublic() internal {
        vm.startPrank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
    }
}
