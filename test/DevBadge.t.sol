// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/DevBadge.sol";

contract DevBadgeTest is Test {

    DevBadge public nft;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    string constant HIDDEN_URI = "ipfs://hidden-metadata";

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Beri ETH ke users untuk mint
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);

        vm.prank(owner);
        nft = new DevBadge(owner, HIDDEN_URI);
    }

    // ── Initialization ────────────────────────────────────────

    function test_Initialization() public view {
        assertEq(nft.name(), "DevBadge");
        assertEq(nft.symbol(), "DBDG");
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.MAX_SUPPLY(), 100);
        assertFalse(nft.revealed());
        assertFalse(nft.publicMintOpen());
        assertFalse(nft.whitelistMintOpen());
    }

    // ── Owner Mint ────────────────────────────────────────────

    function test_OwnerMint() public {
        vm.prank(owner);
        nft.ownerMint(user1);

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), user1);
    }

    function test_RevertWhen_OwnerMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DevBadge.ZeroAddress.selector);
        nft.ownerMint(address(0));
    }

    // ── Whitelist Mint ────────────────────────────────────────

    function test_WhitelistMint() public {
        vm.startPrank(owner);
        nft.toggleWhitelistMint(true);
        address[] memory wl = new address[](1);
        wl[0] = user1;
        nft.addToWhitelist(wl);
        vm.stopPrank();

        vm.prank(user1);
        nft.whitelistMint{value: 0.001 ether}();

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.mintedPerWallet(user1), 1);
    }

    function test_RevertWhen_WhitelistMintNotOpen() public {
        vm.prank(user1);
        vm.expectRevert(DevBadge.MintNotOpen.selector);
        nft.whitelistMint{value: 0.001 ether}();
    }

    function test_RevertWhen_NotWhitelisted() public {
        vm.prank(owner);
        nft.toggleWhitelistMint(true);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(DevBadge.NotWhitelisted.selector, user1)
        );
        nft.whitelistMint{value: 0.001 ether}();
    }

    function test_RevertWhen_WhitelistInsufficientPayment() public {
        vm.startPrank(owner);
        nft.toggleWhitelistMint(true);
        address[] memory wl = new address[](1);
        wl[0] = user1;
        nft.addToWhitelist(wl);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                DevBadge.InsufficientPayment.selector, 0.0005 ether, 0.001 ether
            )
        );
        nft.whitelistMint{value: 0.0005 ether}();
    }

    // ── Public Mint ───────────────────────────────────────────

    function test_PublicMint() public {
        vm.prank(owner);
        nft.togglePublicMint(true);

        vm.prank(user1);
        nft.publicMint{value: 0.002 ether}();

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), user1);
    }

    function test_RevertWhen_PublicMintNotOpen() public {
        vm.prank(user1);
        vm.expectRevert(DevBadge.MintNotOpen.selector);
        nft.publicMint{value: 0.002 ether}();
    }

    function test_MaxPerWalletEnforced() public {
        vm.prank(owner);
        nft.togglePublicMint(true);

        vm.startPrank(user1);
        nft.publicMint{value: 0.002 ether}();
        nft.publicMint{value: 0.002 ether}();
        nft.publicMint{value: 0.002 ether}();

        vm.expectRevert(DevBadge.MaxPerWalletReached.selector);
        nft.publicMint{value: 0.002 ether}();
        vm.stopPrank();
    }

    // ── Metadata ──────────────────────────────────────────────

    function test_HiddenMetadataBeforeReveal() public {
        vm.prank(owner);
        nft.ownerMint(user1);

        string memory uri = nft.tokenURI(1);
        assertEq(uri, HIDDEN_URI);
    }

    function test_OnChainMetadataAfterReveal() public {
        vm.prank(owner);
        nft.ownerMint(user1);

        vm.prank(owner);
        nft.reveal("ipfs://revealed");

        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
        // URI harus dimulai dengan data:application/json;base64,
        assertEq(
            _slice(uri, 0, 29),
            "data:application/json;base64,"
        );
    }

    // ── Withdraw ──────────────────────────────────────────────

    function test_Withdraw() public {
        vm.prank(owner);
        nft.togglePublicMint(true);

        vm.prank(user1);
        nft.publicMint{value: 0.002 ether}();

        uint256 ownerBefore = owner.balance;

        vm.prank(owner);
        nft.withdraw();

        assertEq(owner.balance, ownerBefore + 0.002 ether);
        assertEq(address(nft).balance, 0);
    }

    function test_RevertWhen_WithdrawNoBalance() public {
        vm.prank(owner);
        vm.expectRevert(DevBadge.NoBalanceToWithdraw.selector);
        nft.withdraw();
    }

    // ── Helper ────────────────────────────────────────────────

    function _slice(
        string memory str,
        uint256 start,
        uint256 end
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }
}