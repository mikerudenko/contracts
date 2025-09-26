// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "lib/chimera/src/FoundryAsserts.sol";

import "lib/forge-std/src/console2.sol";

import {Test} from "lib/forge-std/src/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }
}
