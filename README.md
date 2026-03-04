# DevBadge (DBDG)

An ERC-721 NFT collection with whitelist minting, 
public minting, and fully on-chain SVG metadata.

## Features
- Max supply: 100 NFTs
- Whitelist mint: 0.001 ETH (max 3 per wallet)
- Public mint: 0.002 ETH (max 3 per wallet)
- On-chain SVG metadata generated via Base64
- Reveal mechanism (hidden → revealed)
- Owner withdraw ETH from mint proceeds

## Tech Stack
- Solidity 0.8.24
- Foundry
- OpenZeppelin ERC721 + Ownable + Base64

## Deployed Contract
- Network: Sepolia Testnet
- Address: `0xc2b642150B337BcF5f46214a285d942Fae00C9a6`
- Etherscan: [View Contract](https://sepolia.etherscan.io/address/0xc2b642150b337bcf5f46214a285d942fae00c9a6)

## Run Tests
forge test -v

## Deploy
forge script script/DeployDevBadge.s.sol --rpc-url sepolia --broadcast --verify
```