## Smart $M + Uniswap V4 Rewards Distribution Hook

Smart $M (or Wrapped M) is next-gen wrapper contract for the $M cryptodollar. This wrapper maintains a 1:1 rate with $M and offers integrators unprecedented control over yield in DeFi protocols.

**M^0 repositories**:
- [$M](https://github.com/m0-foundation/protocol/blob/main/src/MToken.sol)
- [Smart $M(Wrapped $M)](https://github.com/m0-foundation/wrapped-m-token/blob/main/src/WrappedMToken.sol)

** Uniswap V4 hook idea **
Even though Smart $M allows for earners/protocols to accrue yied, the secondary distribution of such rewards between LP providers and users remains challenging.

Rewards hook simplifies such logic by reliably tracking and claiming rewards by LPs:
- after liquidity was added
- after liqudiity was removed

Additionally, after the pool was initialized, `PoolManager` starts accruing wM rewards.

For calculations of rewards standard shares based staking algorithm is used (multiplier scaling is omitted for simplicity):

```
rewardIndex += reward / totalLiquidity;
lpRewards = lpliquidity * (rewardIndex - lpRewardIndex)
```

**Architecture components**

<img width="900" alt="Screenshot 2024-09-16 at 10 46 49 PM" src="https://github.com/user-attachments/assets/869350fa-de6c-4700-99f4-b035754ae2a0">

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
