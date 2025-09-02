// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    struct Vars {
        // Token balances
        uint256 contractTokenBalance;
        uint128 streamsBalance;
        uint128 splitsBalance;
        // Driver state
        uint32 nextDriverId;
        // Account state tracking
        uint256 totalCollectable;
        uint256 totalSplittable;
        // Stream state
        uint256 totalStreamingBalance;
        // Admin state
        address admin;
        address proposedAdmin;
        bool paused;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts() {
        __before();
        _;
        __after();
    }

    function __before() internal {
        _before.contractTokenBalance = token.balanceOf(address(drips));
        (_before.streamsBalance, _before.splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        _before.nextDriverId = drips.nextDriverId();
        _before.admin = drips.admin();
        _before.proposedAdmin = drips.proposedAdmin();
        _before.paused = drips.isPaused();

        // Calculate total collectable and splittable for tracked accounts
        _before.totalCollectable = _calculateTotalCollectable();
        _before.totalSplittable = _calculateTotalSplittable();
    }

    function __after() internal {
        _after.contractTokenBalance = token.balanceOf(address(drips));
        (_after.streamsBalance, _after.splitsBalance) = drips.balances(
            IERC20(address(token))
        );
        _after.nextDriverId = drips.nextDriverId();
        _after.admin = drips.admin();
        _after.proposedAdmin = drips.proposedAdmin();
        _after.paused = drips.isPaused();

        // Calculate total collectable and splittable for tracked accounts
        _after.totalCollectable = _calculateTotalCollectable();
        _after.totalSplittable = _calculateTotalSplittable();
    }

    function _calculateTotalCollectable()
        internal
        view
        returns (uint256 total)
    {
        // Calculate total collectable across all tracked accounts
        for (uint32 driverId = 1; driverId < nextDriverId; driverId++) {
            uint256 accountId = _getValidAccountId(driverId);
            total += drips.collectable(accountId, IERC20(address(token)));
        }
    }

    function _calculateTotalSplittable() internal view returns (uint256 total) {
        // Calculate total splittable across all tracked accounts
        for (uint32 driverId = 1; driverId < nextDriverId; driverId++) {
            uint256 accountId = _getValidAccountId(driverId);
            total += drips.splittable(accountId, IERC20(address(token)));
        }
    }
}
