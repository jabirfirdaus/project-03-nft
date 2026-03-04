// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DevBadge
 * @author jabirfirdaus
 * @notice NFT collection dengan whitelist, public mint, dan on-chain metadata
 */
contract DevBadge is ERC721, Ownable {
    using Strings for uint256;

    // ─── Constants ─────────────────────────────────────────────
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant WHITELIST_PRICE = 0.001 ether;
    uint256 public constant PUBLIC_PRICE = 0.002 ether;
    uint256 public constant MAX_PER_WALLET = 3;

    // ─── State Variables ───────────────────────────────────────
    uint256 private _tokenIdCounter;
    bool public revealed;
    bool public publicMintOpen;
    bool public whitelistMintOpen;
    string public hiddenMetadataUri;

    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedPerWallet;

    // ─── Errors ────────────────────────────────────────────────
    error MaxSupplyReached();
    error MaxPerWalletReached();
    error InsufficientPayment(uint256 sent, uint256 required);
    error MintNotOpen();
    error NotWhitelisted(address caller);
    error NoBalanceToWithdraw();
    error WithdrawFailed();
    error ZeroAddress();

    // ─── Events ────────────────────────────────────────────────
    event Minted(address indexed to, uint256 indexed tokenId);
    event Revealed(uint256 timestamp);
    event WhitelistUpdated(address indexed account, bool status);
    event Withdrawn(address indexed to, uint256 amount);
    event PublicMintToggled(bool open);
    event WhitelistMintToggled(bool open);

    // ─── Constructor ───────────────────────────────────────────
    constructor(
        address initialOwner,
        string memory _hiddenMetadataUri
    ) ERC721("DevBadge", "DBDG") Ownable(initialOwner) {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    // ─── Mint Functions ────────────────────────────────────────

    /**
     * @notice Mint untuk whitelist — harga lebih murah
     */
    function whitelistMint() external payable {
        if (!whitelistMintOpen) revert MintNotOpen();
        if (!whitelist[msg.sender]) revert NotWhitelisted(msg.sender);
        if (_tokenIdCounter >= MAX_SUPPLY) revert MaxSupplyReached();
        if (mintedPerWallet[msg.sender] >= MAX_PER_WALLET)
            revert MaxPerWalletReached();
        if (msg.value < WHITELIST_PRICE)
            revert InsufficientPayment(msg.value, WHITELIST_PRICE);

        _mintToken(msg.sender);
    }

    /**
     * @notice Mint untuk publik umum
     */
    function publicMint() external payable {
        if (!publicMintOpen) revert MintNotOpen();
        if (_tokenIdCounter >= MAX_SUPPLY) revert MaxSupplyReached();
        if (mintedPerWallet[msg.sender] >= MAX_PER_WALLET)
            revert MaxPerWalletReached();
        if (msg.value < PUBLIC_PRICE)
            revert InsufficientPayment(msg.value, PUBLIC_PRICE);

        _mintToken(msg.sender);
    }

    /**
     * @notice Owner mint gratis — untuk team/giveaway
     */
    function ownerMint(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (_tokenIdCounter >= MAX_SUPPLY) revert MaxSupplyReached();

        _mintToken(to);
    }

    // ─── Internal ──────────────────────────────────────────────

    function _mintToken(address to) internal {
        _tokenIdCounter++;
        mintedPerWallet[to]++;
        _safeMint(to, _tokenIdCounter);
        emit Minted(to, _tokenIdCounter);
    }

    // ─── Metadata ──────────────────────────────────────────────

    /**
     * @notice Generate metadata on-chain via Base64
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);

        if (!revealed) {
            return hiddenMetadataUri;
        }

        string memory svg = _generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"DevBadge #',
                        tokenId.toString(),
                        '",',
                        '"description":"A badge for Web3 developers.",',
                        '"image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '",',
                        '"attributes":[',
                        '{"trait_type":"Token ID","value":',
                        tokenId.toString(),
                        "},",
                        '{"trait_type":"Collection","value":"DevBadge"}',
                        "]}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @notice Generate SVG sederhana on-chain
     */
    function _generateSVG(
        uint256 tokenId
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">',
                    '<rect width="300" height="300" fill="#1a1a2e"/>',
                    '<text x="150" y="130" text-anchor="middle" ',
                    'font-family="monospace" font-size="48" fill="#e94560">',
                    "</text>",
                    '<text x="150" y="180" text-anchor="middle" ',
                    'font-family="monospace" font-size="20" fill="#ffffff">',
                    "DevBadge</text>",
                    '<text x="150" y="220" text-anchor="middle" ',
                    'font-family="monospace" font-size="14" fill="#aaaaaa">',
                    "#",
                    tokenId.toString(),
                    "</text>",
                    "</svg>"
                )
            );
    }

    // ─── Admin Functions ───────────────────────────────────────

    function togglePublicMint(bool _open) external onlyOwner {
        publicMintOpen = _open;
        emit PublicMintToggled(_open);
    }

    function toggleWhitelistMint(bool _open) external onlyOwner {
        whitelistMintOpen = _open;
        emit WhitelistMintToggled(_open);
    }

    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
            emit WhitelistUpdated(addresses[i], true);
        }
    }

    function removeFromWhitelist(
        address[] calldata addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
            emit WhitelistUpdated(addresses[i], false);
        }
    }

    function reveal(string memory _metadataUri) external onlyOwner {
        revealed = true;
        hiddenMetadataUri = _metadataUri;
        emit Revealed(block.timestamp);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalanceToWithdraw();

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit Withdrawn(owner(), balance);
    }

    // ─── View Functions ────────────────────────────────────────

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter;
    }
}