// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import {AddressDriverTargets} from "./targets/AddressDriverTargets.sol";
import {AdminTargets} from "./targets/AdminTargets.sol";
import {DoomsdayTargets} from "./targets/DoomsdayTargets.sol";
import {DripsTargets} from "./targets/DripsTargets.sol";
import {ManagersTargets} from "./targets/ManagersTargets.sol";
import {NFTDriverTargets} from "./targets/NFTDriverTargets.sol";

abstract contract TargetFunctions is
    AddressDriverTargets,
    AdminTargets,
    DoomsdayTargets,
    DripsTargets,
    ManagersTargets,
    NFTDriverTargets
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
