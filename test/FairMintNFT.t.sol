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

    function setUp() external {
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        fairMintNFT = new FairMintNFT(dev, 10);
    }

    function test_CanMintExactlyMaxSupply() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint(10);
        assertEq(fairMintNFT.balanceOf(alice), 10);
        assertEq(fairMintNFT.totalSupply(), 10);
        assertEq(fairMintNFT.ownerOf(1), alice);
        assertEq(fairMintNFT.ownerOf(10), alice);
    }

    function test_RevertWhen_ExceedsMaxSupply() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint(8);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(5);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroQuantity() public {
        _openPublic();
        vm.expectRevert(FairMintNFT.QuantityZero.selector);
        vm.prank(alice);
        fairMintNFT.mint(0);
    }

    function test_RevertWhen_MintAfterSoldOut() public {
        _openPublic();
        vm.startPrank(alice);
        fairMintNFT.mint(10);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(1);
        vm.stopPrank();
    }

    function test_CanMint_TwoUsers() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint(3);
        assertEq(fairMintNFT.ownerOf(3), alice);
        vm.prank(bob);
        fairMintNFT.mint(2);
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
        fairMintNFT.mint(1);
    }

    function test_RevertWhen_MintInAllowlist() public {
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Allowlist)
        );
        fairMintNFT.mint(1);
    }

    function test_RevertWhen_MintInEnded() public {
        _openPublic();
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint(1);
    }

    function test_MintPublic_RevertWhen_MintInEnded() public {
        _openPublic();
        vm.prank(alice);
        fairMintNFT.mint(3);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
        vm.prank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Ended);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FairMintNFT.MintNotPublicStage.selector, FairMintNFT.MintStage.Ended));
        fairMintNFT.mint(4);
        assertEq(fairMintNFT.balanceOf(alice), 3);
        assertEq(fairMintNFT.totalSupply(), 3);
    }

    function _openPublic() internal {
        vm.startPrank(dev);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Allowlist);
        fairMintNFT.changeMintStage(FairMintNFT.MintStage.Public);
        vm.stopPrank();
    }
}
