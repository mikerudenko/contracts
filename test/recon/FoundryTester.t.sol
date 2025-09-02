// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "lib/chimera/src/FoundryAsserts.sol";

/// @notice Foundry test contract for running Recon fuzzing tests
contract FoundryTester is TargetFunctions, FoundryAsserts {
    
    function setUp() public {
        setup();
    }

    /// === PROPERTY TESTS === ///
    
    function test_totalBalanceNeverExceedsTokenBalance() public {
        property_totalBalanceNeverExceedsTokenBalance();
    }
    
    function test_totalBalanceNeverExceedsMax() public {
        property_totalBalanceNeverExceedsMax();
    }
    
    function test_withdrawableAmountIsValid() public {
        property_withdrawableAmountIsValid();
    }
    
    function test_driverIdsAreSequential() public {
        property_driverIdsAreSequential();
    }
    
    function test_onlyRegisteredDriversCanControlAccounts() public {
        property_onlyRegisteredDriversCanControlAccounts();
    }

    /// === FUZZ TESTS === ///
    
    function testFuzz_registerDriver(uint256 seed) public {
        drips_registerDriverFuzz(seed);
        
        // Check properties after operation
        property_driverIdsAreSequential();
        property_onlyRegisteredDriversCanControlAccounts();
    }
    
    function testFuzz_setStreams(
        uint256 accountSeed,
        uint256 balanceSeed,
        uint256 receiversSeed,
        uint256 hintSeed
    ) public {
        drips_setStreamsFuzz(accountSeed, balanceSeed, receiversSeed, hintSeed);
        
        // Check properties after operation
        property_totalBalanceNeverExceedsTokenBalance();
        property_totalBalanceNeverExceedsMax();
        property_streamBalanceConsistency();
    }
    
    function testFuzz_give(
        uint256 accountSeed,
        uint256 receiverSeed,
        uint256 amountSeed
    ) public {
        drips_giveFuzz(accountSeed, receiverSeed, amountSeed);
        
        // Check properties after operation
        property_totalBalanceNeverExceedsTokenBalance();
        property_splitsBalanceConsistency();
    }
    
    function testFuzz_setSplits(
        uint256 accountSeed,
        uint256 receiversSeed
    ) public {
        drips_setSplitsFuzz(accountSeed, receiversSeed);
        
        // Check properties after operation
        property_totalBalanceNeverExceedsTokenBalance();
    }
    
    function testFuzz_collect(uint256 accountSeed) public {
        drips_collectFuzz(accountSeed);
        
        // Check properties after operation
        property_totalBalanceNeverExceedsTokenBalance();
        property_collectableAndSplittableConsistency();
    }
    
    function testFuzz_withdraw(
        uint256 receiverSeed,
        uint256 amountSeed
    ) public {
        drips_withdrawFuzz(receiverSeed, amountSeed);
        
        // Check properties after operation
        property_totalBalanceNeverExceedsTokenBalance();
        property_withdrawableAmountIsValid();
        property_tokenConservation();
    }

    /// === SEQUENCE TESTS === ///
    
    function testFuzz_multipleOperations(
        uint256 seed1,
        uint256 seed2,
        uint256 seed3,
        uint256 seed4
    ) public {
        // Perform multiple operations in sequence
        drips_registerDriverFuzz(seed1);
        drips_setStreamsFuzz(seed1, seed2, seed3, seed4);
        drips_giveFuzz(seed2, seed3, seed4);
        drips_setSplitsFuzz(seed3, seed4);
        drips_collectFuzz(seed4);
        
        // Check all properties
        property_totalBalanceNeverExceedsTokenBalance();
        property_totalBalanceNeverExceedsMax();
        property_withdrawableAmountIsValid();
        property_driverIdsAreSequential();
        property_onlyRegisteredDriversCanControlAccounts();
        property_streamBalanceConsistency();
        property_splitsBalanceConsistency();
        property_tokenConservation();
        property_collectableAndSplittableConsistency();
    }
}
