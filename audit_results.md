# Audit Results

## Contract: Splits.sol
### Invariants
- The sum of all splittable and collectable balances across all accounts must never exceed the total ERC-20 tokens held by the protocol
- Total splits weight must never exceed `_TOTAL_SPLITS_WEIGHT` (1,000,000)
- Each splits receiver weight must be greater than zero
- Splits receivers list must be sorted by account ID and deduplicated
- The maximum number of splits receivers per account is `_MAX_SPLITS_RECEIVERS` (200)
- Collectable balance can only increase through splitting or giving, never decrease except through collection
- Splittable balance can only increase through receiving funds, never decrease except through splitting

### Properties
- When `_split()` is called, the entire splittable balance is distributed according to current splits configuration
- When `_collect()` is called, the entire collectable balance is transferred to the caller and balance becomes zero
- When `_give()` is called, the specified amount is added to the receiver's splittable balance
- When `_setSplits()` is called with valid receivers, the splits hash is updated and events are emitted
- Split amounts are calculated proportionally: `amount * weight / _TOTAL_SPLITS_WEIGHT`

---

## Contract: Streams.sol
### Invariants
- The maximum streams balance per token is `_MAX_STREAMS_BALANCE` (2^127 - 1)
- Each stream's `amtPerSec` must be at least `_minAmtPerSec` (1 token per cycle)
- Maximum number of stream receivers per account is `_MAX_STREAMS_RECEIVERS` (100)
- Stream receivers must be sorted by account ID and configuration, deduplicated, with non-zero `amtPerSec`
- Cycle length (`_cycleSecs`) must be greater than 1
- Stream history hashes must form a valid chain linking configurations chronologically
- Squeezed amounts can never exceed the total streamed amount for a given time period

### Properties
- When `_receiveStreams()` is called, funds from completed cycles are moved from streams to splits balance
- When `_squeezeStreams()` is called, funds from current cycle are immediately available for splitting
- When `_setStreams()` is called, the new configuration takes effect immediately for future streaming
- Stream balance decreases linearly over time according to the sum of all `amtPerSec` values
- When streams run out of balance, streaming stops automatically at the calculated `maxEnd` timestamp
- Squeezed funds are deducted from the current cycle's receivable amount

---

## Contract: Drips.sol
### Invariants
- Total protocol balance (streams + splits) must never exceed `MAX_TOTAL_BALANCE` (2^127 - 1)
- Total protocol balance must never exceed actual ERC-20 token balance held by the contract
- Driver IDs are unique and assigned sequentially starting from 0
- Account IDs are deterministically derived: `driverId (32 bits) | driverCustomData (224 bits)`
- Only registered drivers can control accounts within their ID range
- Withdrawable funds = actual token balance - (streams balance + splits balance)

### Properties
- When `collect()` is called, funds move from splits balance to withdrawable (decreasing protocol balance)
- When `give()` is called, funds move from withdrawable to splits balance (increasing protocol balance)
- When `setStreams()` is called with positive balance delta, funds move from withdrawable to streams balance
- When `setStreams()` is called with negative balance delta, funds move from streams to withdrawable
- When `receiveStreams()` or `squeezeStreams()` is called, funds move from streams to splits balance
- Only the controlling driver can perform operations on accounts within its range

---

## Contract: AddressDriver.sol
### Invariants
- Each Ethereum address maps to exactly one account ID: `driverId (32 bits) | zeros (64 bits) | address (160 bits)`
- Account ID calculation is deterministic and collision-free
- Only the address owner can control their corresponding account
- Driver ID is immutable after deployment

### Properties
- When `collect()` is called, funds are transferred directly to the specified address
- When `give()` is called, tokens are transferred from caller's wallet to the protocol
- When `setStreams()` is called, token transfers occur to/from caller's wallet based on balance delta
- When `setSplits()` is called, the configuration applies to all ERC-20 tokens for that account

---

## Contract: ImmutableSplitsDriver.sol
### Invariants
- Account IDs are assigned sequentially: `driverId (32 bits) | counter (224 bits)`
- Once created, splits configurations cannot be modified (immutable)
- Total splits weight must equal `totalSplitsWeight` (100% distribution)
- Account counter only increases, never decreases
- No account owner exists (accounts are permissionless)

### Properties
- When `createSplits()` is called, a new account is created with immutable splits configuration
- The sum of all receiver weights must exactly equal `totalSplitsWeight`
- Account metadata can only be emitted during account creation
- Created accounts automatically distribute 100% of received funds

---

## Contract: NFTDriver.sol
### Invariants
- Each NFT token ID equals its corresponding account ID
- Token IDs are deterministic: `driverId (32 bits) | minter (160 bits) | salt (64 bits)` or `driverId (32 bits) | zeros (160 bits) | counter (64 bits)`
- Each minter can use each salt only once
- Only token holder (owner or approved) can control the account
- Token counter only increases for non-salt minting

### Properties
- When `mint()` or `safeMint()` is called, a new token and account are created
- When `mintWithSalt()` is called, the token ID is deterministically derived from minter and salt
- When token is transferred, account control transfers to the new owner
- When `burn()` is called, the account becomes permanently uncontrollable
- Token holder can perform all account operations (collect, give, setStreams, setSplits)

---

## Cross-Contract Invariants & Properties
### Between Drips and All Drivers
- Driver registration in Drips must precede any driver operations
- Account ID ranges are exclusive to each driver (no overlap)
- All driver operations must go through the Drips contract for state changes
- Token balance consistency: sum of all driver-controlled balances ≤ Drips contract token balance

### Between Streams and Splits (within Drips)
- Funds flow: Streams → Splits → Collectable → Withdrawable
- When streams are received/squeezed, they become splittable in the splits system
- Total balance conservation: streams balance + splits balance + withdrawable = total tokens held
- Cross-system operations maintain balance invariants

### Between BridgedGovernor and Drips
- Only authorized cross-chain messages can trigger governance actions
- Message nonces must be sequential to prevent replay attacks
- Governance operations can modify any contract state through delegated calls
- Bridge message validation must occur before execution

### Between RepoDriver and RepoDeadlineDriver
- RepoDeadlineDriver depends on RepoDriver for account ownership verification
- Account ownership status in RepoDriver determines fund distribution in RepoDeadlineDriver
- Both drivers share the same underlying Drips instance for consistency

### Between All Drivers and Managed
- All drivers inherit pause functionality from Managed
- Admin controls affect all driver operations simultaneously
- Upgrade mechanisms are consistent across all managed contracts
- Pause state prevents all user-facing operations across drivers

### Between RepoDriver and Gelato Integration
- Gelato task execution must be authorized through the designated proxy
- Fee payment flows from user deposits → common funds → Gelato fee collector
- Request rate limiting prevents spam through gas penalty mechanism
- Oracle responses update account ownership atomically

---

## Contract: BridgedGovernor.sol
### Invariants
- Message nonces must be sequential and never decrease
- Only authorized cross-chain sources can execute messages
- Implementation address can only be changed through self-upgrade
- Message execution must be atomic (all calls succeed or all fail)

### Properties
- When `lzReceive()` is called with valid LayerZero message, governance calls are executed
- When `execute()` is called with valid Axelar message, governance calls are executed
- Message nonce increments exactly by 1 after successful execution
- Reentrancy protection prevents nonce manipulation during execution

---

## Contract: RepoDeadlineDriver.sol
### Invariants
- Account IDs are deterministic: `driverId (32 bits) | accountsHash (192 bits) | deadline (32 bits)`
- Fund distribution depends on repo claim status and deadline
- Only one of recipient or refund account can receive funds per call
- Account parameters (repo, recipient, refund, deadline) are immutable once calculated

### Properties
- When `collectAndGive()` is called and repo is claimed, funds go to recipient account
- When `collectAndGive()` is called and repo is unclaimed after deadline, funds go to refund account
- When `collectAndGive()` is called and repo is unclaimed before deadline, no funds are distributed
- Account visibility event is emitted on every interaction regardless of fund distribution

---

## Contract: RepoDriver.sol
### Invariants
- Account IDs are deterministic based on forge and repository name
- Repository ownership can only be updated through Gelato oracle
- Gas penalty mechanism prevents spam and enforces rate limits
- User funds and common funds are segregated and tracked separately

### Properties
- When `requestUpdateOwner()` is called, an event is emitted and gas penalty is applied
- When `updateOwnerByGelato()` is called by authorized proxy, ownership is updated and fees are paid
- When user funds are insufficient for fees, common funds cover the difference
- Repository name encoding handles both short names (≤27 bytes) and long names (>27 bytes) differently
