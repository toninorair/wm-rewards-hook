// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseHook } from "v4-periphery/src/base/hooks/BaseHook.sol";
import { PositionConfig, PositionConfigLibrary } from "v4-periphery/src/libraries/PositionConfig.sol";

import { CurrencyLibrary, Currency } from "v4-core/types/Currency.sol";
import { BalanceDeltaLibrary, BalanceDelta } from "v4-core/types/BalanceDelta.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";

import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { IPositionManager } from "v4-periphery/src/interfaces/IPositionManager.sol";

import { IWrappedMTokenLike, IERC721Like, IERC20Like } from "./interfaces/Dependencies.sol";
import { IWrappedMRewardsHook } from "./interfaces/IWrappedMRewardsHook.sol";

import { ISubscriber } from "v4-periphery/src/interfaces/ISubscriber.sol";

// TODO: unchecked math
// TODO: bitpacking
// TODO: more sophisticated distribution from PoolManager between multiple pools
// TODO: adjust liqudity for multiple NFTs
// TODO: figure out how to retrieve `PositionConfig` from `tokenId`

/**
 * @title Wrapped M Token Rewards Hook
 * @author 0xt0n1
 */
contract WrappedMRewardsHook is IWrappedMRewardsHook, ISubscriber, BaseHook {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;
    using PositionConfigLibrary for PositionConfig;

    uint256 internal constant _MULTIPLIER = 1e18;

    /// @inheritdoc IWrappedMRewardsHook
    address public immutable positionManager;

    /// @inheritdoc IWrappedMRewardsHook
    address public immutable wrappedMToken;

    // Note: bitpacking here is highly desirable, but doesn't look valid
    /// @inheritdoc IWrappedMRewardsHook
    mapping(address lp => uint256 liquidity) public lpLiquidityOf;

    // TODO: find more optimal way to do it
    /// @inheritdoc IWrappedMRewardsHook
    mapping(uint256 tokenId => uint256 liquidity) public nftLiquidityOf;

    /// @inheritdoc IWrappedMRewardsHook
    mapping(address lp => uint256 rewardIndex) public rewardIndexOf;

    /// @inheritdoc IWrappedMRewardsHook
    uint256 public rewardIndex;

    /// @inheritdoc IWrappedMRewardsHook
    uint256 public totalLiquidity;

    /// @inheritdoc IWrappedMRewardsHook
    uint256 public totalRewards;

    /* ============ Constructor ============ */

    constructor(
        address poolManager_,
        address positionManager_,
        address wrappedMToken_
    ) BaseHook(IPoolManager(poolManager_)) {
        if ((positionManager = positionManager_) == address(0)) revert ZeroPositionManager();
        if ((wrappedMToken = wrappedMToken_) == address(0)) revert ZeroWrappedMToken();
    }

    /* ============ Hook functions ============ */

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /**
     * @notice Hook function called after the pool is initialized.
     */
    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24,
        bytes calldata
    ) external override onlyByPoolManager returns (bytes4) {
        // TODO consider revert here to avoid initialization of non-wM pools
        if (!_isValidWrappedMPool(key)) return this.afterInitialize.selector;

        // Start earning wM yield for both Pool Manager and Hook contracts itself
        // PoolManager and Hook are TTG approved earners.

        IWrappedMTokenLike(wrappedMToken).startEarningFor(address(poolManager));
        // IWrappedMTokenLike(wrappedMToken).startEarningFor(address(this));

        return this.afterInitialize.selector;
    }

    /**
     * @notice Hook function called after liquidity is added to the pool.
     */
    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyByPoolManager returns (bytes4, BalanceDelta) {
        if (!_isValidWrappedMPool(key)) return (this.afterAddLiquidity.selector, delta);

        _adjustLiquidity(params);

        uint256 tokenId_ = uint256(params.salt);

        // Unfortunately, no way to subscribe when position was minted
        if (uint256(IPositionManager(positionManager).getPositionConfigId(tokenId_)) == 0)
            return (this.afterAddLiquidity.selector, delta);

        if (!IPositionManager(positionManager).hasSubscriber(tokenId_)) {
            IPositionManager(positionManager).subscribe(
                tokenId_,
                PositionConfig({ poolKey: key, tickLower: params.tickLower, tickUpper: params.tickUpper }),
                address(this)
            );
        }

        return (this.afterAddLiquidity.selector, delta);
    }

    /**
     * @notice Hook function called after liquidity is removed from the pool.
     */
    function afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyByPoolManager returns (bytes4, BalanceDelta) {
        if (!_isValidWrappedMPool(key)) return (this.afterRemoveLiquidity.selector, delta);

        _adjustLiquidity(params);

        return (this.afterRemoveLiquidity.selector, delta);
    }

    /* ============ Rewards/Claims Interactive functions ============ */

    /// @inheritdoc IWrappedMRewardsHook
    function claimFor(address lp_) public returns (uint256) {
        // Fully distribute all rewards and adjust global reward index before claiming
        distributeRewards();

        // Calculate the reward for the liquidity provider
        uint256 reward_ = (lpLiquidityOf[lp_] * (rewardIndex - rewardIndexOf[lp_])) / _MULTIPLIER;

        // Update total rewards and update lp's reward index
        totalRewards -= reward_;
        rewardIndexOf[lp_] = rewardIndex;

        // Transfer the reward to the liquidity provider
        IERC20Like(wrappedMToken).transfer(lp_, reward_);

        emit RewardsClaimed(msg.sender, lp_, reward_);

        return reward_;
    }

    /// @inheritdoc IWrappedMRewardsHook
    function distributeRewards() public returns (uint256) {
        // If pool has no liquidity, no rewards to distribute
        if (totalLiquidity == 0) return 0;

        uint256 claimed_ = IWrappedMTokenLike(wrappedMToken).claimFor(address(poolManager));
        // IWrappedMTokenLike(wrappedMToken).claimFor(address(this));

        // Total distributable rewards can be > than claimed rewards if `claimFor` called outside of this contract
        uint256 reward_ = IERC20Like(wrappedMToken).balanceOf(address(this)) - totalRewards;

        // Upgate global reward index and total rewards
        rewardIndex += (reward_ * _MULTIPLIER) / totalLiquidity;
        totalRewards += reward_;

        emit RewardsDistributed(msg.sender, claimed_, reward_, rewardIndex);

        return reward_;
    }

    /* ============ Subscriber functions ============ */

    // TODO: adjust liqudity for multiple token ids
    function notifyTransfer(uint256 tokenId_, address previousOwner_, address newOwner_) external {
        // Claim rewards for the previous owner of token id
        claimFor(previousOwner_);

        // Adjust liquidity position from previous owner to new owner after transfer
        lpLiquidityOf[previousOwner_] -= nftLiquidityOf[tokenId_];
        lpLiquidityOf[newOwner_] += nftLiquidityOf[tokenId_];
    }

    function notifyModifyLiquidity(uint256 tokenId_, PositionConfig memory config_, int256 liquidityChange_) external {}

    function notifySubscribe(uint256 tokenId_, PositionConfig memory config_) external {}

    function notifyUnsubscribe(uint256 tokenId_, PositionConfig memory config_) external {}

    /* ============  Internal functions ============ */

    /**
     * @dev   Increases or descreases total liqudity shares and liquidity of individual provider.
     * @param params The parameters of the liquidity modification.
     */
    function _adjustLiquidity(IPoolManager.ModifyLiquidityParams calldata params) internal {
        // Get the position ID and owner of NFT that represents the liquidity
        uint256 tokenId_ = uint256(params.salt);
        address lp_ = IERC721Like(positionManager).ownerOf(tokenId_);

        // Claim rewards for the owner of token id
        claimFor(lp_);

        if (params.liquidityDelta < 0) {
            uint256 liquidityDelta_ = uint256(int256(-params.liquidityDelta));

            // Decrease the total liquidity and the liquidity of the lp and nft position
            totalLiquidity -= liquidityDelta_;
            lpLiquidityOf[lp_] -= liquidityDelta_;
            nftLiquidityOf[tokenId_] -= liquidityDelta_;
        } else {
            uint256 liquidityDelta_ = uint256(params.liquidityDelta);

            // Increase the total liquidity and the liquidity of the lp and nft position
            totalLiquidity += liquidityDelta_;
            lpLiquidityOf[lp_] += liquidityDelta_;
            nftLiquidityOf[tokenId_] += liquidityDelta_;
        }
    }

    /**
     * @dev   Checks if Uniswap V4 pool is eligible for the Wrapped M rewards.
     *        Checks if `currency0` or `currency` is wrappedM.
     * @param key The pool key.
     * @return True if the pool is a valid
     */
    function _isValidWrappedMPool(PoolKey calldata key) internal view returns (bool) {
        return Currency.unwrap(key.currency0) == wrappedMToken || Currency.unwrap(key.currency1) == wrappedMToken;
    }
}
