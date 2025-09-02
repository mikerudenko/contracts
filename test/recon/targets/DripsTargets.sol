// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "lib/chimera/src/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "lib/chimera/src/Hevm.sol";

import "src/Drips.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {StreamReceiver, StreamConfigImpl} from "src/Streams.sol";
import {SplitsReceiver} from "src/Splits.sol";

abstract contract DripsTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// @notice Register a new driver with fuzzing
    function drips_registerDriverFuzz(uint256 seed) public updateGhosts {
        address driverAddr = _getActorByIndex(seed % 10);

        // Skip if driver address is zero or already registered
        if (driverAddr == address(0)) return;

        try drips.registerDriver(driverAddr) returns (uint32 driverId) {
            registeredDrivers[driverId] = driverAddr;
            if (nextDriverId <= driverId) {
                nextDriverId = driverId + 1;
            }
        } catch {
            // Registration failed, which is expected in some cases
        }
    }

    /// @notice Set streams with fuzzing and validation
    function drips_setStreamsFuzz(
        uint256 accountSeed,
        uint256 balanceSeed,
        uint256 receiversSeed,
        uint256 hintSeed
    ) public updateGhosts {
        // Get a valid account ID
        uint32 driverId = _getValidDriverId();
        uint256 accountId = _getValidAccountId(driverId);
        address driverAddr = registeredDrivers[driverId];

        if (driverAddr == address(0)) return;

        // Create balance delta (can be positive or negative)
        int128 balanceDelta = int128(
            int256(bound(balanceSeed, 0, 1000 * 10 ** 18))
        );
        if (balanceSeed % 2 == 0) balanceDelta = -balanceDelta;

        // Create receivers array
        StreamReceiver[] memory newReceivers = new StreamReceiver[](
            bound(receiversSeed, 0, 3)
        );
        for (uint256 i = 0; i < newReceivers.length; i++) {
            newReceivers[i] = _createValidStreamReceiver(receiversSeed + i);
        }

        // Create hints
        uint32 hint1 = uint32(bound(hintSeed, 0, type(uint32).max));
        uint32 hint2 = uint32(bound(hintSeed >> 32, 0, type(uint32).max));

        // Get current receivers (empty for first call)
        StreamReceiver[] memory currReceivers = new StreamReceiver[](0);

        vm.prank(driverAddr);
        try
            drips.setStreams(
                accountId,
                IERC20(address(token)),
                currReceivers,
                balanceDelta,
                newReceivers,
                hint1,
                hint2
            )
        {
            // Success
        } catch {
            // Expected to fail in many cases due to insufficient balance, etc.
        }
    }

    /// @notice Give tokens with fuzzing
    function drips_giveFuzz(
        uint256 accountSeed,
        uint256 receiverSeed,
        uint256 amountSeed
    ) public updateGhosts {
        uint32 driverId = _getValidDriverId();
        uint256 accountId = _getValidAccountId(driverId);
        uint256 receiverId = _getValidAccountId(_getValidDriverId());
        address driverAddr = registeredDrivers[driverId];

        if (driverAddr == address(0)) return;

        uint128 amount = uint128(bound(amountSeed, 0, 1000 * 10 ** 18));

        // Ensure contract has enough tokens
        if (token.balanceOf(address(drips)) < amount) {
            token.mint(address(drips), amount);
        }

        vm.prank(driverAddr);
        try drips.give(accountId, receiverId, IERC20(address(token)), amount) {
            // Success
        } catch {
            // Expected to fail in some cases
        }
    }

    /// @notice Set splits with fuzzing
    function drips_setSplitsFuzz(
        uint256 accountSeed,
        uint256 receiversSeed
    ) public updateGhosts {
        uint32 driverId = _getValidDriverId();
        uint256 accountId = _getValidAccountId(driverId);
        address driverAddr = registeredDrivers[driverId];

        if (driverAddr == address(0)) return;

        // Create splits receivers
        uint256 numReceivers = bound(receiversSeed, 0, 5);
        SplitsReceiver[] memory receivers = new SplitsReceiver[](numReceivers);

        uint32 totalWeight = 0;
        for (uint256 i = 0; i < numReceivers; i++) {
            receivers[i] = _createValidSplitsReceiver(receiversSeed + i);
            totalWeight += receivers[i].weight;

            // Ensure we don't exceed total weight
            if (totalWeight > drips.TOTAL_SPLITS_WEIGHT()) {
                receivers[i].weight =
                    drips.TOTAL_SPLITS_WEIGHT() -
                    (totalWeight - receivers[i].weight);
                break;
            }
        }

        vm.prank(driverAddr);
        try drips.setSplits(accountId, receivers) {
            // Success
        } catch {
            // Expected to fail in some cases
        }
    }

    /// @notice Collect funds with fuzzing
    function drips_collectFuzz(uint256 accountSeed) public updateGhosts {
        uint32 driverId = _getValidDriverId();
        uint256 accountId = _getValidAccountId(driverId);
        address driverAddr = registeredDrivers[driverId];

        if (driverAddr == address(0)) return;

        vm.prank(driverAddr);
        try drips.collect(accountId, IERC20(address(token))) {
            // Success
        } catch {
            // Expected to fail if no funds to collect
        }
    }

    /// @notice Withdraw funds with fuzzing
    function drips_withdrawFuzz(
        uint256 receiverSeed,
        uint256 amountSeed
    ) public updateGhosts {
        address receiver = _getActorByIndex(receiverSeed % 10);

        // Calculate withdrawable amount
        (uint128 streamsBalance, uint128 splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        uint256 contractBalance = token.balanceOf(address(drips));

        if (
            contractBalance <= uint256(streamsBalance) + uint256(splitsBalance)
        ) {
            return; // Nothing to withdraw
        }

        uint256 withdrawable = contractBalance -
            uint256(streamsBalance) -
            uint256(splitsBalance);
        uint256 amount = bound(amountSeed, 0, withdrawable);

        if (amount == 0) return;

        try drips.withdraw(IERC20(address(token)), receiver, amount) {
            // Success
        } catch {
            // Expected to fail in some cases
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function drips_acceptAdmin() public asActor {
        drips.acceptAdmin();
    }

    function drips_collect(uint256 accountId, IERC20 erc20) public asActor {
        drips.collect(accountId, erc20);
    }

    function drips_emitAccountMetadata(
        uint256 accountId,
        AccountMetadata[] memory accountMetadata
    ) public asActor {
        drips.emitAccountMetadata(accountId, accountMetadata);
    }

    function drips_give(
        uint256 accountId,
        uint256 receiver,
        IERC20 erc20,
        uint128 amt
    ) public asActor {
        drips.give(accountId, receiver, erc20, amt);
    }

    function drips_grantPauser(address pauser) public asActor {
        drips.grantPauser(pauser);
    }

    function drips_pause() public asActor {
        drips.pause();
    }

    function drips_proposeNewAdmin(address newAdmin) public asActor {
        drips.proposeNewAdmin(newAdmin);
    }

    function drips_receiveStreams(
        uint256 accountId,
        IERC20 erc20,
        uint32 maxCycles
    ) public asActor {
        drips.receiveStreams(accountId, erc20, maxCycles);
    }

    function drips_registerDriver(address driverAddr) public asActor {
        drips.registerDriver(driverAddr);
    }

    function drips_renounceAdmin() public asActor {
        drips.renounceAdmin();
    }

    function drips_revokePauser(address pauser) public asActor {
        drips.revokePauser(pauser);
    }

    function drips_setSplits(
        uint256 accountId,
        SplitsReceiver[] memory receivers
    ) public asActor {
        drips.setSplits(accountId, receivers);
    }

    function drips_setStreams(
        uint256 accountId,
        IERC20 erc20,
        StreamReceiver[] memory currReceivers,
        int128 balanceDelta,
        StreamReceiver[] memory newReceivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2
    ) public asActor {
        drips.setStreams(
            accountId,
            erc20,
            currReceivers,
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2
        );
    }

    function drips_split(
        uint256 accountId,
        IERC20 erc20,
        SplitsReceiver[] memory currReceivers
    ) public asActor {
        drips.split(accountId, erc20, currReceivers);
    }

    function drips_squeezeStreams(
        uint256 accountId,
        IERC20 erc20,
        uint256 senderId,
        bytes32 historyHash,
        StreamsHistory[] memory streamsHistory
    ) public asActor {
        drips.squeezeStreams(
            accountId,
            erc20,
            senderId,
            historyHash,
            streamsHistory
        );
    }

    function drips_unpause() public asActor {
        drips.unpause();
    }

    function drips_updateDriverAddress(
        uint32 driverId,
        address newDriverAddr
    ) public asActor {
        drips.updateDriverAddress(driverId, newDriverAddr);
    }

    function drips_upgradeTo(address newImplementation) public asActor {
        drips.upgradeTo(newImplementation);
    }

    function drips_upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable asActor {
        drips.upgradeToAndCall{value: msg.value}(newImplementation, data);
    }

    function drips_withdraw(
        IERC20 erc20,
        address receiver,
        uint256 amt
    ) public asActor {
        drips.withdraw(erc20, receiver, amt);
    }
}
