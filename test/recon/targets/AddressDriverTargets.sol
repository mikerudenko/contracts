// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "../Setup.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {AddressDriver} from "src/AddressDriver.sol";
import {AccountMetadata, SplitsReceiver, StreamReceiver, StreamConfigImpl} from "src/Drips.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {vm} from "lib/chimera/src/Hevm.sol";

/// @title AddressDriver Target Functions
/// @notice Target functions for fuzzing AddressDriver contract
abstract contract AddressDriverTargets is Setup, BeforeAfter {
    AddressDriver public addressDriver;
    uint32 public addressDriverId;

    function setupAddressDriver() internal {
        // Register AddressDriver
        addressDriverId = drips.registerDriver(address(this));
        addressDriver = new AddressDriver(drips, address(0), addressDriverId);
    }

    /// @notice Fuzz collect operation for AddressDriver
    function addressDriver_collectFuzz(uint256 actorSeed) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address actor = _getActorByIndex(actorSeed % 10);

        vm.prank(actor);
        try addressDriver.collect(IERC20(address(token)), actor) {
            // Collection succeeded
        } catch {
            // Expected to fail if nothing to collect or other constraints
        }
    }

    /// @notice Fuzz give operation for AddressDriver
    function addressDriver_giveFuzz(
        uint256 giverSeed,
        uint256 receiverSeed,
        uint256 amountSeed
    ) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address giver = _getActorByIndex(giverSeed % 10);
        address receiver = _getActorByIndex(receiverSeed % 10);

        uint256 giverAccountId = addressDriver.calcAccountId(giver);
        uint256 receiverAccountId = addressDriver.calcAccountId(receiver);

        uint128 amount = uint128(bound(amountSeed, 0, 1000 * 10 ** 18));

        // Ensure giver has enough tokens
        if (token.balanceOf(giver) < amount) {
            token.mint(giver, amount);
        }

        vm.prank(giver);
        try
            addressDriver.give(
                receiverAccountId,
                IERC20(address(token)),
                amount
            )
        {
            // Give operation succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz setSplits operation for AddressDriver
    function addressDriver_setSplitsFuzz(
        uint256 accountSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address owner = _getActorByIndex(accountSeed % 10);
        uint256 accountId = addressDriver.calcAccountId(owner);

        // Create splits receivers
        uint256 numReceivers = bound(receiversSeed, 0, 5);
        SplitsReceiver[] memory receivers = new SplitsReceiver[](numReceivers);

        uint32 totalWeight = 0;
        for (uint256 i = 0; i < numReceivers; i++) {
            address receiverAddr = _getActorByIndex((receiversSeed + i) % 10);
            uint256 receiverAccountId = addressDriver.calcAccountId(
                receiverAddr
            );
            uint32 weight = uint32(bound(receiversSeed + i, 1, 200000));

            receivers[i] = SplitsReceiver({
                accountId: receiverAccountId,
                weight: weight
            });
            totalWeight += weight;
        }

        // Ensure total weight doesn't exceed maximum
        if (totalWeight > drips.TOTAL_SPLITS_WEIGHT()) {
            return; // Skip this configuration
        }

        vm.prank(owner);
        try addressDriver.setSplits(receivers) {
            // SetSplits succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz setStreams operation for AddressDriver
    function addressDriver_setStreamsFuzz(
        uint256 accountSeed,
        uint256 balanceSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address owner = _getActorByIndex(accountSeed % 10);
        uint256 accountId = addressDriver.calcAccountId(owner);

        // Create balance delta
        int128 balanceDelta = int128(
            int256(bound(balanceSeed, 0, 1000 * 10 ** 18))
        );
        if (balanceSeed % 2 == 0) balanceDelta = -balanceDelta;

        // Create stream receivers
        uint256 numReceivers = bound(receiversSeed, 0, 3);
        StreamReceiver[] memory newReceivers = new StreamReceiver[](
            numReceivers
        );

        for (uint256 i = 0; i < numReceivers; i++) {
            newReceivers[i] = _createValidStreamReceiver(receiversSeed + i);
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
            addressDriver.setStreams(
                IERC20(address(token)),
                new StreamReceiver[](0), // currReceivers
                balanceDelta,
                newReceivers,
                0, // maxEndHint1
                0, // maxEndHint2
                address(0) // transferTo
            )
        {
            // SetStreams succeeded
        } catch {
            // May fail due to various constraints
        }
    }

    /// @notice Fuzz split operation for AddressDriver
    function addressDriver_splitFuzz(
        uint256 accountSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address owner = _getActorByIndex(accountSeed % 10);
        uint256 accountId = addressDriver.calcAccountId(owner);

        // Create splits receivers for the split operation
        uint256 numReceivers = bound(receiversSeed, 0, 5);
        SplitsReceiver[] memory receivers = new SplitsReceiver[](numReceivers);

        for (uint256 i = 0; i < numReceivers; i++) {
            address receiverAddr = _getActorByIndex((receiversSeed + i) % 10);
            uint256 receiverAccountId = addressDriver.calcAccountId(
                receiverAddr
            );
            uint32 weight = uint32(bound(receiversSeed + i, 1, 200000));

            receivers[i] = SplitsReceiver({
                accountId: receiverAccountId,
                weight: weight
            });
        }

        // AddressDriver doesn't have a split function - splits are handled by the core Drips contract
        // This function is removed
    }

    /// @notice Fuzz emitAccountMetadata operation for AddressDriver
    function addressDriver_emitAccountMetadataFuzz(
        uint256 accountSeed,
        uint256 metadataSeed
    ) public updateGhosts {
        if (address(addressDriver) == address(0)) {
            setupAddressDriver();
        }

        address owner = _getActorByIndex(accountSeed % 10);
        uint256 accountId = addressDriver.calcAccountId(owner);

        // Create some metadata
        AccountMetadata[] memory metadata = new AccountMetadata[](1);
        metadata[0] = AccountMetadata({
            key: bytes32(metadataSeed),
            value: abi.encode("test metadata", metadataSeed)
        });

        vm.prank(owner);
        try addressDriver.emitAccountMetadata(metadata) {
            // Metadata emission succeeded
        } catch {
            // May fail due to various constraints
        }
    }
}
