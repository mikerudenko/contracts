// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "../Setup.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {NFTDriver} from "src/NFTDriver.sol";
import {AccountMetadata, SplitsReceiver, StreamReceiver, StreamConfigImpl} from "src/Drips.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {vm} from "lib/chimera/src/Hevm.sol";

/// @title NFTDriver Target Functions
/// @notice Target functions for fuzzing NFTDriver contract
abstract contract NFTDriverTargets is Setup, BeforeAfter {
    NFTDriver public nftDriver;
    uint32 public nftDriverId;
    uint256[] public mintedTokens;

    function setupNFTDriver() internal {
        // Register NFTDriver
        nftDriverId = drips.registerDriver(address(this));
        nftDriver = new NFTDriver(drips, address(0), nftDriverId);
    }

    /// @notice Fuzz mint operation for NFTDriver
    function nftDriver_mintFuzz(uint256 minterSeed) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        address minter = _getActorByIndex(minterSeed % 10);

        vm.prank(minter);
        try nftDriver.mint(minter, new AccountMetadata[](0)) returns (
            uint256 tokenId
        ) {
            mintedTokens.push(tokenId);
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz mint with salt operation for NFTDriver
    function nftDriver_mintWithSaltFuzz(
        uint256 minterSeed,
        uint256 saltSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        address minter = _getActorByIndex(minterSeed % 10);
        uint64 salt = uint64(bound(saltSeed, 0, type(uint64).max));

        vm.prank(minter);
        try
            nftDriver.safeMintWithSalt(salt, minter, new AccountMetadata[](0))
        returns (uint256 tokenId) {
            mintedTokens.push(tokenId);
        } catch {
            // May fail if salt already used or other constraints
        }
    }

    /// @notice Fuzz collect operation for NFTDriver
    function nftDriver_collectFuzz(uint256 tokenSeed) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length == 0) return;

        uint256 tokenId = mintedTokens[tokenSeed % mintedTokens.length];
        address owner = nftDriver.ownerOf(tokenId);

        vm.prank(owner);
        try nftDriver.collect(tokenId, IERC20(address(token)), owner) {
            // Collection succeeded
        } catch {
            // Expected to fail if nothing to collect
        }
    }

    /// @notice Fuzz give operation for NFTDriver
    function nftDriver_giveFuzz(
        uint256 giverTokenSeed,
        uint256 receiverTokenSeed,
        uint256 amountSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length < 2) return;

        uint256 giverTokenId = mintedTokens[
            giverTokenSeed % mintedTokens.length
        ];
        uint256 receiverTokenId = mintedTokens[
            receiverTokenSeed % mintedTokens.length
        ];

        address giver = nftDriver.ownerOf(giverTokenId);
        uint128 amount = uint128(bound(amountSeed, 0, 1000 * 10 ** 18));

        // Ensure giver has enough tokens
        if (token.balanceOf(giver) < amount) {
            token.mint(giver, amount);
        }

        vm.prank(giver);
        try
            nftDriver.give(
                giverTokenId,
                receiverTokenId,
                IERC20(address(token)),
                amount
            )
        {
            // Give operation succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz setSplits operation for NFTDriver
    function nftDriver_setSplitsFuzz(
        uint256 tokenSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length == 0) return;

        uint256 tokenId = mintedTokens[tokenSeed % mintedTokens.length];
        address owner = nftDriver.ownerOf(tokenId);

        // Create splits receivers
        uint256 numReceivers = bound(receiversSeed, 0, 5);
        SplitsReceiver[] memory receivers = new SplitsReceiver[](numReceivers);

        uint32 totalWeight = 0;
        for (uint256 i = 0; i < numReceivers && i < mintedTokens.length; i++) {
            uint256 receiverTokenId = mintedTokens[
                (receiversSeed + i) % mintedTokens.length
            ];
            uint32 weight = uint32(bound(receiversSeed + i, 1, 200000));

            receivers[i] = SplitsReceiver({
                accountId: receiverTokenId,
                weight: weight
            });
            totalWeight += weight;
        }

        // Ensure total weight doesn't exceed maximum
        if (totalWeight > drips.TOTAL_SPLITS_WEIGHT()) {
            return; // Skip this configuration
        }

        vm.prank(owner);
        try nftDriver.setSplits(tokenId, receivers) {
            // SetSplits succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz setStreams operation for NFTDriver
    function nftDriver_setStreamsFuzz(
        uint256 tokenSeed,
        uint256 balanceSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length == 0) return;

        uint256 tokenId = mintedTokens[tokenSeed % mintedTokens.length];
        address owner = nftDriver.ownerOf(tokenId);

        // Create balance delta
        int128 balanceDelta = int128(
            int256(bound(balanceSeed, 0, 1000 * 10 ** 18))
        );
        if (balanceSeed % 2 == 0) balanceDelta = -balanceDelta;

        // Create stream receivers using existing tokens
        uint256 numReceivers = bound(receiversSeed, 0, 3);
        if (numReceivers > mintedTokens.length)
            numReceivers = mintedTokens.length;

        StreamReceiver[] memory newReceivers = new StreamReceiver[](
            numReceivers
        );

        for (uint256 i = 0; i < numReceivers; i++) {
            uint256 receiverTokenId = mintedTokens[
                (receiversSeed + i) % mintedTokens.length
            ];
            uint160 amtPerSec = uint160(
                bound(
                    receiversSeed + i,
                    drips.minAmtPerSec(),
                    type(uint160).max / 1000
                )
            );

            newReceivers[i] = StreamReceiver({
                accountId: receiverTokenId,
                config: StreamConfigImpl.create(0, amtPerSec, 0, 0)
            });
        }

        // Ensure owner has enough tokens if balance delta is positive
        if (balanceDelta > 0) {
            uint128 needed = uint128(balanceDelta);
            if (token.balanceOf(owner) < needed) {
                token.mint(owner, needed);
            }
        }

        vm.prank(owner);
        try
            nftDriver.setStreams(
                tokenId,
                IERC20(address(token)),
                new StreamReceiver[](0), // currReceivers
                balanceDelta,
                newReceivers,
                0, // maxEndHint
                0, // transferTo
                address(0) // transferTo
            )
        {
            // SetStreams succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz transfer operation for NFTDriver
    function nftDriver_transferFuzz(
        uint256 tokenSeed,
        uint256 toSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length == 0) return;

        uint256 tokenId = mintedTokens[tokenSeed % mintedTokens.length];
        address from = nftDriver.ownerOf(tokenId);
        address to = _getActorByIndex(toSeed % 10);

        if (from != to) {
            vm.prank(from);
            try nftDriver.transferFrom(from, to, tokenId) {
                // Transfer succeeded
            } catch {
                // May fail due to various constraints
            }
        }
    }

    /// @notice Fuzz split operation for NFTDriver
    function nftDriver_splitFuzz(
        uint256 tokenSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(nftDriver) == address(0)) {
            setupNFTDriver();
        }

        if (mintedTokens.length == 0) return;

        uint256 tokenId = mintedTokens[tokenSeed % mintedTokens.length];
        address owner = nftDriver.ownerOf(tokenId);

        // Create splits receivers for the split operation
        uint256 numReceivers = bound(receiversSeed, 0, 5);
        if (numReceivers > mintedTokens.length)
            numReceivers = mintedTokens.length;

        SplitsReceiver[] memory receivers = new SplitsReceiver[](numReceivers);

        for (uint256 i = 0; i < numReceivers; i++) {
            uint256 receiverTokenId = mintedTokens[
                (receiversSeed + i) % mintedTokens.length
            ];
            uint32 weight = uint32(bound(receiversSeed + i, 1, 200000));

            receivers[i] = SplitsReceiver({
                accountId: receiverTokenId,
                weight: weight
            });
        }

        // NFTDriver doesn't have a split function - splits are handled by the core Drips contract
        // This function is removed
    }
}
