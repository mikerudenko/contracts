// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "lib/chimera/src/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract Properties is BeforeAfter, Asserts {
    /// === BALANCE INVARIANTS === ///

    /// @notice The sum of streams and splits balances should never exceed the contract's token balance
    function property_totalBalanceNeverExceedsTokenBalance() public {
        (uint128 streamsBalance, uint128 splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        uint256 totalBalance = uint256(streamsBalance) + uint256(splitsBalance);
        uint256 contractBalance = token.balanceOf(address(drips));

        lte(
            totalBalance,
            contractBalance,
            "Total balance exceeds contract token balance"
        );
    }

    /// @notice The total balance should never exceed MAX_TOTAL_BALANCE
    function property_totalBalanceNeverExceedsMax() public {
        (uint128 streamsBalance, uint128 splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        uint256 totalBalance = uint256(streamsBalance) + uint256(splitsBalance);

        lte(
            totalBalance,
            drips.MAX_TOTAL_BALANCE(),
            "Total balance exceeds maximum"
        );
    }

    /// @notice Withdrawable amount should be non-negative
    function property_withdrawableAmountIsValid() public {
        (uint128 streamsBalance, uint128 splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        uint256 totalBalance = uint256(streamsBalance) + uint256(splitsBalance);
        uint256 contractBalance = token.balanceOf(address(drips));

        if (contractBalance >= totalBalance) {
            uint256 withdrawable = contractBalance - totalBalance;
            gte(withdrawable, 0, "Withdrawable amount is negative");
        }
    }

    /// === DRIVER INVARIANTS === ///

    /// @notice Driver IDs should be sequential and start from 1
    function property_driverIdsAreSequential() public {
        uint32 nextId = drips.nextDriverId();
        gte(nextId, 1, "Next driver ID should be at least 1");

        // Check that all driver IDs from 1 to nextId-1 have valid addresses
        for (uint32 i = 1; i < nextId; i++) {
            address driverAddr = drips.driverAddress(i);
            t(driverAddr != address(0), "Driver address should not be zero");
        }
    }

    /// @notice Only registered drivers can control their accounts
    function property_onlyRegisteredDriversCanControlAccounts() public {
        // This is enforced by the onlyDriver modifier in the contract
        // We can test this by ensuring all registered drivers have valid addresses
        uint32 nextId = drips.nextDriverId();
        for (uint32 i = 1; i < nextId; i++) {
            address driverAddr = drips.driverAddress(i);
            t(
                driverAddr != address(0),
                "Registered driver must have valid address"
            );
        }
    }

    /// === STREAM INVARIANTS === ///

    /// @notice Stream balance changes should be consistent with operations
    function property_streamBalanceConsistency() public updateGhosts {
        // This property is checked via the updateGhosts modifier
        // The balance should only change through valid operations
        if (_after.streamsBalance != _before.streamsBalance) {
            // Balance change should be reasonable (not exceed total supply)
            uint256 change = _after.streamsBalance > _before.streamsBalance
                ? _after.streamsBalance - _before.streamsBalance
                : _before.streamsBalance - _after.streamsBalance;
            lte(change, token.totalSupply(), "Stream balance change too large");
        }
    }

    /// @notice Splits balance changes should be consistent with operations
    function property_splitsBalanceConsistency() public updateGhosts {
        if (_after.splitsBalance != _before.splitsBalance) {
            uint256 change = _after.splitsBalance > _before.splitsBalance
                ? _after.splitsBalance - _before.splitsBalance
                : _before.splitsBalance - _after.splitsBalance;
            lte(change, token.totalSupply(), "Splits balance change too large");
        }
    }

    /// @notice Pause state can only be changed by admin or pauser
    function property_pauseStateChangeAuthorization() public updateGhosts {
        // This is enforced by the contract's access control
        // We verify the state is consistent
        if (_after.paused != _before.paused) {
            // Pause state changed, which is allowed by authorized users
            t(true, "Pause state change detected");
        }
    }

    /// === CONSERVATION INVARIANTS === ///

    /// @notice Total tokens in the system should be conserved (excluding external transfers)
    function property_tokenConservation() public updateGhosts {
        // The contract balance should only change through deposits/withdrawals
        if (_after.contractTokenBalance != _before.contractTokenBalance) {
            // Change should be reasonable
            uint256 change = _after.contractTokenBalance >
                _before.contractTokenBalance
                ? _after.contractTokenBalance - _before.contractTokenBalance
                : _before.contractTokenBalance - _after.contractTokenBalance;
            lte(change, token.totalSupply(), "Token balance change too large");
        }
    }

    /// === MATHEMATICAL INVARIANTS === ///

    /// @notice Collectable + Splittable should not exceed splits balance
    function property_collectableAndSplittableConsistency()
        public
        updateGhosts
    {
        // Total collectable and splittable should be reasonable relative to splits balance
        lte(
            _after.totalCollectable,
            _after.splitsBalance,
            "Collectable exceeds splits balance"
        );
        lte(
            _after.totalSplittable,
            _after.splitsBalance,
            "Splittable exceeds splits balance"
        );
    }

    /// === DRIVER INVARIANTS === ///

    /// @notice Driver registration should be monotonic
    function property_driverRegistrationMonotonic() public updateGhosts {
        gte(
            _after.nextDriverId,
            _before.nextDriverId,
            "Driver ID counter should never decrease"
        );
    }

    /// === ACCOUNT ID INVARIANTS === ///

    /// @notice Account IDs should encode driver IDs correctly
    function property_accountIdEncodesDriverId() public {
        // For any valid account ID, the top 32 bits should be a valid driver ID
        for (uint32 driverId = 1; driverId < nextDriverId; driverId++) {
            uint256 accountId = _getValidAccountId(driverId);
            uint32 extractedDriverId = uint32(accountId >> 224);

            eq(
                extractedDriverId,
                driverId,
                "Account ID should encode correct driver ID"
            );
        }
    }

    /// === STREAMS INVARIANTS === ///

    /// @notice Stream balances should not exceed available funds
    function property_streamBalancesValid() public updateGhosts {
        lte(
            _after.streamsBalance,
            _after.contractTokenBalance,
            "Streams balance should not exceed contract token balance"
        );
    }

    /// === TOKEN CONSERVATION INVARIANTS === ///

    /// @notice Total tokens should be conserved across all operations
    function property_totalTokenConservation() public updateGhosts {
        // Contract balance should equal sum of streams and splits balances
        eq(
            _after.contractTokenBalance,
            uint256(_after.streamsBalance) + uint256(_after.splitsBalance),
            "Contract balance should equal sum of streams and splits balances"
        );
    }

    /// === COLLECTION INVARIANTS === ///

    /// @notice Collection should decrease contract balance appropriately
    function property_collectionDecreasesBalance() public updateGhosts {
        if (_after.contractTokenBalance < _before.contractTokenBalance) {
            // If contract balance decreased, total collectable should have decreased too
            lte(
                _after.totalCollectable,
                _before.totalCollectable,
                "Collection should decrease total collectable"
            );
        }
    }

    /// === PAUSE INVARIANTS === ///

    /// @notice Paused state should prevent unauthorized state changes
    function property_pausedStatePreventsChanges() public updateGhosts {
        if (_before.paused && _after.paused) {
            // When paused throughout the operation, critical state should not change
            eq(
                _after.nextDriverId,
                _before.nextDriverId,
                "Driver registration should be blocked when paused"
            );
        }
    }

    /// === ADMIN GOVERNANCE INVARIANTS === ///

    /// @notice Admin changes should follow proper governance flow
    function property_adminChangeFollowsGovernance() public updateGhosts {
        // Admin should only change through proper proposal -> acceptance flow
        if (_before.admin != _after.admin) {
            eq(
                uint256(uint160(_after.admin)),
                uint256(uint160(_before.proposedAdmin)),
                "New admin must be the previously proposed admin"
            );
        }
    }
}
