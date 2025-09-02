// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "lib/chimera/src/BaseSetup.sol";
import {vm} from "lib/chimera/src/Hevm.sol";

// Managers
import {ActorManager} from "lib/setup-helpers/src/ActorManager.sol";
import {AssetManager} from "lib/setup-helpers/src/AssetManager.sol";

// Helpers
import {Utils} from "lib/setup-helpers/src/Utils.sol";
import {Test} from "lib/forge-std/src/Test.sol";

// Your deps
import "src/Drips.sol";
import {ManagedProxy} from "src/Managed.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils, Test {
    Drips drips;
    MockERC20 token;

    // Constants for testing
    uint32 constant CYCLE_SECS = 604800; // 1 week
    uint256 constant MAX_DRIVERS = 10;
    uint256 constant MAX_ACCOUNTS_PER_DRIVER = 100;

    // State tracking
    mapping(uint32 => address) public registeredDrivers;
    mapping(uint256 => bool) public validAccountIds;
    uint32 public nextDriverId = 1;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        // Create Drips logic contract and proxy with admin
        Drips dripsLogic = new Drips(CYCLE_SECS);
        drips = Drips(address(new ManagedProxy(dripsLogic, address(this), "")));
        token = new MockERC20("Test Token", "TEST");

        // Register some initial drivers for testing
        _registerInitialDrivers();

        // Mint tokens to actors
        _setupTokens();
    }

    function _registerInitialDrivers() internal {
        // Add some actors first
        for (uint32 i = 0; i < 3; i++) {
            address actor = address(uint160(0x1000 + i));
            _addActor(actor);
        }

        for (uint32 i = 0; i < 3; i++) {
            address driverAddr = _getActorByIndex(i);
            vm.prank(address(this));
            uint32 driverId = drips.registerDriver(driverAddr);
            registeredDrivers[driverId] = driverAddr;
        }
        nextDriverId = 4;
    }

    function _setupTokens() internal {
        // Mint tokens to the contract and actors
        token.mint(address(drips), 1000000 * 10 ** 18);
        for (uint256 i = 0; i < 10; i++) {
            address actor = _getActorByIndex(i);
            token.mint(actor, 100000 * 10 ** 18);
        }
    }

    /// === HELPER FUNCTIONS === ///

    function _getActorByIndex(uint256 index) internal view returns (address) {
        address[] memory actors = _getActors();
        if (actors.length == 0) return address(this);
        return actors[index % actors.length];
    }

    function _getValidDriverId() internal view returns (uint32) {
        if (nextDriverId <= 1) return 1;
        return
            uint32(
                bound(
                    uint256(keccak256(abi.encode(block.timestamp))),
                    1,
                    nextDriverId - 1
                )
            );
    }

    function _getValidAccountId(
        uint32 driverId
    ) internal pure returns (uint256) {
        return
            (uint256(driverId) << 224) |
            (uint256(keccak256(abi.encode(driverId))) >> 32);
    }

    function _createValidStreamReceiver(
        uint256 seed
    ) internal view returns (StreamReceiver memory) {
        uint256 accountId = _getValidAccountId(_getValidDriverId());
        uint160 amtPerSec = uint160(
            bound(seed, drips.minAmtPerSec(), type(uint160).max / 1000)
        );
        return
            StreamReceiver({
                accountId: accountId,
                config: StreamConfigImpl.create(0, amtPerSec, 0, 0)
            });
    }

    function _createValidSplitsReceiver(
        uint256 seed
    ) internal view returns (SplitsReceiver memory) {
        uint256 accountId = _getValidAccountId(_getValidDriverId());
        uint32 weight = uint32(bound(seed, 1, drips.TOTAL_SPLITS_WEIGHT()));
        return SplitsReceiver({accountId: accountId, weight: weight});
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor

    modifier asAdmin() {
        vm.prank(address(this));
        _;
    }

    modifier asActor() {
        vm.prank(address(_getActor()));
        _;
    }

    modifier asValidDriver(uint256 accountId) {
        uint32 driverId = uint32(accountId >> 224);
        address driverAddr = registeredDrivers[driverId];
        require(driverAddr != address(0), "Invalid driver");
        vm.prank(driverAddr);
        _;
    }
}
