// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title  Hook distributing rewards for the Uniswap V4 pool Wrapped M Token
 * @author 0xt0n1
 */
interface IWrappedMRewardsHook {
    /// @notice Emitted when the rewards are claimed for the Liquidity Provider.
    event RewardsClaimed(address indexed caller, address indexed lp, uint256 amount);

    /// @notice Emitted when the Wrapped M Token rewards are distributed from the pool.
    event RewardsDistributed(address indexed caller, uint256 claimed, uint256 distributed, uint256 rewardIndex);

    /// @notice Emitted in constructor if Uniswap V4 Position Manager is 0x0.
    error ZeroPositionManager();

    /// @notice Emitted in constructor if Wrapped M Token is 0x0.
    error ZeroWrappedMToken();

    /**
     * @notice Returns the address of the Wrapped M Token.
     * @return The address of the Wrapped M Token.
     */
    function wrappedMToken() external view returns (address);

    /**
     * @notice Returns the address of the position manager.
     * @return The address of the position manager.
     */
    function positionManager() external view returns (address);

    /**
     * @notice Returns the system global reward index.
     */
    function rewardIndex() external view returns (uint256);

    /**
     * @notice Returns the last saved reward index of the specific Liquidity Provider.
     * @param lp the address of the LP.
     * @return the reward index of the LP.
     */
    function rewardIndexOf(address lp) external view returns (uint256);

    /**
     * @notice Returns the total liquidity supplied to the pool.
     */
    function totalLiquidity() external view returns (uint256);

    /**
     * @notice Returns the liquidity supplied to the pool by the specific Liquidity Provider.
     * @param lp the address of the LP.
     * @return The liquidity of the LP.
     */
    function lpLiquidityOf(address lp) external view returns (uint256);

    /*
     * @notice Returns the liquidity associated with specific NFT token id.
     * @param tokenId the ERC721 tokenId.
     * @return The liquidity associated with the specific NFT.
     */
    function nftLiquidityOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the total rewards accumulated, but not yet claimed by Liquidity Providers.
     */
    function totalRewards() external view returns (uint256);

    /**
     * @notice Claims and distributes wM token rewards.
     * @return the amount of rewards distributed from the pool.
     */
    function distributeRewards() external returns (uint256);

    /**
     * @notice Claims rewards for the specific Liquidity Providers.
     * @param lp the address of the LP.
     * @return the amount of rewards claimed
     */
    function claimFor(address lp) external returns (uint256);
}
