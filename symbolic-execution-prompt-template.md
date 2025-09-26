# Symbolic Execution Analysis Template for Smart Contracts

## Overview

This template provides a comprehensive guide for performing symbolic execution analysis on the smart contract `{CONTRACT_NAME}` using `{TOOL}`. Symbolic execution is a powerful technique that explores multiple execution paths simultaneously by treating inputs as symbolic variables rather than concrete values.

## Prerequisites

### Environment Setup

1. **Install Required Tools**:

   - For **Hevm**: Install via `nix-env -iA nixpkgs.haskellPackages.hevm` or build from source
   - For **Mythril**: Install via `pip3 install mythril` or Docker
   - For **Manticore**: Install via `pip3 install manticore[native]`

2. **Install SMT Solvers** (recommended for optimal performance):

   - **Z3**: Default solver for most tools
   - **Yices2**: Often faster for bitvector operations
   - **CVC5**: Good alternative solver
   - **Boolector**: Specialized for bitvector logic

3. **Prepare Contract Files**:
   - Source code: `{CONTRACT_NAME}.sol`
   - Compiled bytecode: `{CONTRACT_NAME}.bin-runtime` (for hevm)
   - ABI file: `{CONTRACT_NAME}.abi` (for result interpretation)

## Tool-Specific Configuration

### Hevm Configuration

```bash
# Basic symbolic execution
hevm symbolic --code $(<{CONTRACT_NAME}.bin-runtime)

# With concrete storage (recommended for performance)
hevm symbolic --code $(<{CONTRACT_NAME}.bin-runtime) --storage-model InitialS

# With specific solver
hevm symbolic --code $(<{CONTRACT_NAME}.bin-runtime) --solver z3
```

### Mythril Configuration

```bash
# Basic analysis (single transaction)
myth a {CONTRACT_NAME}.sol -t1

# Optimized analysis with delayed constraint solving
myth a {CONTRACT_NAME}.sol -t1 \
   --solver-timeout 10000000 \
   --sparse-pruning 0 \
   -m Exceptions

# Multi-transaction analysis
myth a {CONTRACT_NAME}.sol -t2 --execution-timeout 300
```

### Manticore Configuration

```bash
# Basic analysis with optimizations
manticore {CONTRACT_NAME}.sol --thorough-mode \
   --txlimit 1 \
   --only-invalid-testcases

# Exclude specific vulnerability types for performance
manticore {CONTRACT_NAME}.sol --thorough-mode \
   --txlimit 1 \
   --only-invalid-testcases \
   --exclude 'overflow,uninitialized-storage,uninitialized-memory,reentrancy,reentrancy-adv,unused-return,suicidal,delegatecall,ext-call-leak,env-instr,lockdrop'

# Use concrete hash strategy to avoid false positives
manticore {CONTRACT_NAME}.sol --thorough-mode \
   --only-invalid-testcases \
   --evm.sha3 concretize
```

## Analysis Workflow

### Step 1: Initial Assessment

1. **Identify Target Functions**: Focus on `external` and `public` functions
2. **Determine Analysis Scope**:
   - Single transaction vs. multi-transaction sequences
   - Specific vulnerability types vs. comprehensive analysis
3. **Set Performance Expectations**:
   - Simple contracts: seconds to minutes
   - Complex contracts: minutes to hours

### Step 2: Basic Execution

Execute the tool with basic parameters:

**For {TOOL}:**

```bash
# Insert tool-specific basic command here based on configuration above
```

### Step 3: Performance Optimization

If initial execution is slow or times out:

1. **Reduce Scope**:

   - Limit to single transactions (`-t1` for Mythril, `--txlimit 1` for Manticore)
   - Focus on specific vulnerability types
   - Make non-essential functions `internal`

2. **Optimize Solver Configuration**:

   - Try different solvers (Z3, Yices2, CVC5)
   - Increase solver timeout for complex queries
   - Use concrete storage models when possible

3. **Enable Performance Features**:
   - **Delayed constraint solving**: `--sparse-pruning 0` (Mythril)
   - **Concrete hash handling**: `--evm.sha3 concretize` (Manticore)
   - **Exclude irrelevant detectors**: `--exclude` flag (Manticore)

### Step 4: Result Analysis

1. **Interpret Outputs**:

   - **Counterexamples**: Concrete input values that trigger vulnerabilities
   - **Execution traces**: Step-by-step execution paths
   - **Coverage reports**: Which code paths were explored

2. **Validate Findings**:
   - Test counterexamples with concrete execution
   - Verify vulnerability claims manually
   - Check for false positives (especially with hash operations)

## Expected Outputs and Interpretation

### Successful Vulnerability Detection

- **Assertion failures**: Failed `assert()` statements
- **Reachability violations**: Unreachable code that becomes reachable
- **State inconsistencies**: Invalid contract states
- **Input validation bypasses**: Unexpected execution paths

### Performance Metrics to Monitor

- **Execution time**: Should complete within reasonable timeframes
- **Constraint solving time**: High percentage indicates solver bottlenecks
- **Memory usage**: Monitor for memory exhaustion
- **Path explosion**: Number of explored execution paths

## Common Issues and Troubleshooting

### Performance Problems

**Symptoms**: Long execution times, high memory usage, timeouts
**Solutions**:

- Reduce transaction limits
- Enable delayed constraint solving
- Use faster solvers (Yices2, Boolector)
- Simplify contract by making functions `internal`
- Increase solver timeouts cautiously

### False Positives

**Symptoms**: Reported vulnerabilities that don't exist in practice
**Solutions**:

- Use concrete hash strategies (`--evm.sha3 concretize`)
- Validate findings with concrete testing
- Check solver assumptions and model limitations

### Tool-Specific Issues

**Hevm**:

- Storage model selection affects performance significantly
- CVC5 solver may fail where Z3 succeeds
- Limited to single-transaction analysis

**Mythril**:

- Z3-only solver support may cause performance issues
- Constraint solving timeouts are common
- Sparse pruning dramatically improves performance

**Manticore**:

- Expression rewriting overhead
- Disk I/O for state management
- Hash collision false positives with default settings

## Best Practices

### Contract Preparation

1. **Simplify for Analysis**: Make non-critical functions `internal`
2. **Add Assertions**: Include `assert()` statements for invariants
3. **Minimize External Dependencies**: Reduce inter-contract calls
4. **Use Clear Function Visibility**: Explicit `external`/`public` declarations

### Analysis Strategy

1. **Start Simple**: Begin with single-transaction analysis
2. **Iterative Refinement**: Gradually increase complexity
3. **Tool Comparison**: Use multiple tools for validation
4. **Performance Monitoring**: Track execution metrics

### Result Validation

1. **Concrete Testing**: Verify symbolic results with actual inputs
2. **Manual Review**: Understand the vulnerability mechanism
3. **False Positive Filtering**: Distinguish real issues from tool artifacts
4. **Documentation**: Record findings and analysis parameters

## Advanced Techniques

### Concolic Execution

Combine symbolic execution with concrete testing for better coverage and performance.

### Symbolic Testing

Use symbolic execution on parameterized tests rather than entire contracts.

### Custom Property Verification

Define specific properties to verify rather than relying on built-in detectors.

## Tool-Specific Deep Dive

### Hevm Detailed Configuration

```bash
# Complete command structure
hevm symbolic \
    --code $(<{CONTRACT_NAME}.bin-runtime) \
    --storage-model InitialS \
    --solver z3 \
    --ask-smt-iterations 1000

# Alternative solvers
hevm symbolic --code $(<{CONTRACT_NAME}.bin-runtime) --solver cvc5
```

**Key Features**:

- Integrated with dapptools ecosystem
- Default lazy constraint evaluation
- Symbolic storage support
- Fast execution for single transactions
- Limited to one transaction sequences

**Performance Notes**:

- Z3 solver recommended for most cases
- CVC5 may fail on complex queries
- Storage model significantly affects performance
- `--ask-smt-iterations` controls loop exploration depth

### Mythril Detailed Configuration

```bash
# Complete optimization flags
myth a {CONTRACT_NAME}.sol \
    -t1 \
    --solver-timeout 10000000 \
    --sparse-pruning 0 \
    --pruning-factor 0 \
    -m Exceptions \
    --execution-timeout 300

# Path exploration strategies
myth a {CONTRACT_NAME}.sol --strategy dfs  # depth-first
myth a {CONTRACT_NAME}.sol --strategy bfs  # breadth-first
myth a {CONTRACT_NAME}.sol --strategy random
```

**Key Features**:

- Highly configurable path exploration
- Multiple vulnerability detectors
- Good UX and documentation
- Delayed constraint solving support
- Z3-only solver limitation

**Performance Notes**:

- Sparse pruning (`--sparse-pruning 0`) crucial for performance
- Constraint solving often dominates execution time
- Query hashing reduces solver invocations
- Mutation pruning helps multi-transaction analysis

### Manticore Detailed Configuration

```bash
# Complete optimization setup
manticore {CONTRACT_NAME}.sol \
    --thorough-mode \
    --txlimit 1 \
    --only-invalid-testcases \
    --exclude 'overflow,uninitialized-storage,uninitialized-memory,reentrancy,reentrancy-adv,unused-return,suicidal,delegatecall,ext-call-leak,env-instr,lockdrop' \
    --evm.sha3 concretize \
    --workspace /tmp/manticore_workspace

# Multi-solver support
manticore {CONTRACT_NAME}.sol --solver yices
manticore {CONTRACT_NAME}.sol --solver boolector
```

**Key Features**:

- Multiple APIs (Python, CLI, verifier)
- Extensive solver support
- Configurable gas metering and ETH balance modeling
- Multiple hash handling strategies
- Experimental lazy constraint evaluation

**Performance Notes**:

- Expression rewriting overhead significant
- 20-25% time spent on disk I/O for state management
- Yices2 often faster than Z3 for bitvector operations
- Hash strategy affects false positive rate

## Vulnerability Detection Patterns

### Common Vulnerability Types Detected

1. **Assertion Failures**:

   ```solidity
   assert(condition); // Will be flagged if condition can be false
   ```

2. **Integer Overflow/Underflow**:

   ```solidity
   uint256 result = a + b; // Flagged if overflow possible
   ```

3. **Reentrancy Vulnerabilities**:

   ```solidity
   external_call(); // Flagged if state changes after external calls
   ```

4. **Uninitialized Storage**:
   ```solidity
   uint256 uninitialized; // Flagged if used before assignment
   ```

### Analysis Depth Configuration

- **Single Transaction**: Fast, limited scope
- **Multi-Transaction**: Comprehensive, slower
- **Bounded Analysis**: Balance between coverage and performance

## Practical Examples and Benchmarks

### MiniVat Contract Analysis Results

Based on the article's benchmarks:

**EthBMC Performance**:

- Single transaction: ~22 seconds
- Two transactions: ~6 minutes (with optimizations)
- Command: `ethbmc examples/Vat/MiniVat_2tx.yml --solver yices`

**Manticore Performance**:

- Single transaction: ~22 seconds (optimized)
- Two transactions: ~6 minutes (with concrete hash)
- Significant improvement with exclusion flags

**Hevm Performance**:

- Internal functions version: ~2 minutes
- Full contract: ~5.5 minutes
- Storage model crucial for performance

**Mythril Performance**:

- Optimized single transaction: ~1.5 minutes
- Requires sparse pruning and timeout adjustments
- Solver timeout often the bottleneck

## Integration Strategies

### Foundry Integration

```bash
# Symbolic testing approach
forge test --symbolic {CONTRACT_NAME}
```

### CI/CD Pipeline Integration

```yaml
# Example GitHub Actions workflow
- name: Symbolic Execution Analysis
  run: |
    {TOOL} {CONTRACT_NAME}.sol > analysis_results.txt
    # Parse and report results
```

### Development Workflow

1. **Unit Testing**: Start with concrete tests
2. **Symbolic Testing**: Add symbolic execution for edge cases
3. **Property Verification**: Define and verify contract invariants
4. **Continuous Analysis**: Integrate into development pipeline

## Conclusion

Symbolic execution is a powerful but complex technique requiring careful configuration and interpretation. Success depends on:

- Proper tool selection and configuration
- Understanding performance trade-offs
- Systematic approach to result validation
- Iterative refinement of analysis parameters

The analysis of `{CONTRACT_NAME}` using `{TOOL}` should follow this structured approach for optimal results.

## References and Further Reading

- [Symbolic Execution Tutorial](https://github.com/WilfredTA/formal-methods-curriculum/blob/master/courses/2_Approaches_Modeling_Verification/content/1_Symbolic_Execution/symbolic_execution.md)
- [Manticore Exercise](https://github.com/WilfredTA/formal-methods-curriculum/blob/master/courses/2_Approaches_Modeling_Verification/exercises/1_Symbolic_Execution/exercise_1.md)
- [Z3 Development Exercise](https://github.com/WilfredTA/formal-methods-curriculum/blob/master/courses/2_Approaches_Modeling_Verification/exercises/1_Symbolic_Execution/exercise_2.md)
- [Hevm Documentation](https://hevm.dev/symbolic.html)
- [Trail of Bits Manticore Guide](https://ethereum.org/en/developers/tutorials/how-to-use-manticore-to-find-smart-contract-bugs/)
