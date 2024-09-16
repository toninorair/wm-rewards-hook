// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console2 } from "forge-std/Test.sol";

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { PoolSwapTest } from "v4-core/test/PoolSwapTest.sol";
import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";

import { PoolManager } from "v4-core/PoolManager.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";

import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";

import { Hooks } from "v4-core/libraries/Hooks.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { SqrtPriceMath } from "v4-core/libraries/SqrtPriceMath.sol";
import { LiquidityAmounts } from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import { PosmTestSetup } from "v4-periphery/test/shared/PosmTestSetup.sol";

import { WrappedMRewardsHook } from "../src/WrappedMRewardsHook.sol";
import { IWrappedMTokenLike, IERC721Like } from "../src/interfaces/Dependencies.sol";

import { MockWrappedMToken } from "./MockWrappedMToken.sol";

import { PositionConfig } from "v4-periphery/src/libraries/PositionConfig.sol";

import { IERC721Like } from "../src/interfaces/Dependencies.sol";

contract TestWMRewardsHook is Test, Deployers, PosmTestSetup {
    using CurrencyLibrary for Currency;

    MockWrappedMToken wMToken; // Mocked Wrapped MToken
    MockERC20 token; // Mocked ERC20 token, counterpart to wMToken

    Currency tokenCurrency;
    Currency wMTokenCurrency;

    WrappedMRewardsHook wMHook;

    function setUp() public {
        // Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy mocked TOKEN contract
        token = new MockERC20("Test Token", "TEST", 6);
        tokenCurrency = Currency.wrap(address(token));

        // Deploy mocked Wrapped MToken contract
        wMToken = new MockWrappedMToken("Wrapped MToken", "wMT", 6);
        wMTokenCurrency = Currency.wrap(address(wMToken));

        // TODO - figure out the propoper way to set it
        currency0 = tokenCurrency;
        currency1 = wMTokenCurrency;

        // Mint a bunch of tokens to the contract
        token.mint(address(this), 10_000e6);
        wMToken.mint(address(this), 10_000e6);

        // Deploy wMHook to an address that has the proper flags set
        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_INITIALIZE_FLAG
        );

        deployPosm(manager);

        approvePosmCurrency(tokenCurrency);
        approvePosmCurrency(wMTokenCurrency);
        // approvePosmCurrency(currency1);
        // approvePosm();
        // deployAndApprovePosm(manager);

        deployCodeTo(
            "WrappedMRewardsHook.sol",
            abi.encode(address(manager), address(lpm), address(wMToken)),
            address(flags)
        );

        // Deploy WrappedMRewardsHook contract
        wMHook = WrappedMRewardsHook(address(flags));

        wMToken.setHook(address(wMHook));

        // Approve token and wMToken for spending on modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
        wMToken.approve(address(modifyLiquidityRouter), type(uint256).max);

        lpm.setApprovalForAll(address(wMHook), true);

        // Initialize a pool
        (key, ) = initPool(
            tokenCurrency, // Currency 0 = token
            wMTokenCurrency, // Currency 1 = wMToken
            wMHook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1, // Initial Sqrt(P) value = 1
            ZERO_BYTES // No additional `initData`
        );
    }

    function test_initialMint() public {
        // uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        // uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        // (uint256 amount0Delta, uint256 amount1Delta) = LiquidityAmounts
        //     .getAmountsForLiquidity(
        //         SQRT_PRICE_1_1,
        //         sqrtPriceAtTickLower,
        //         sqrtPriceAtTickUpper,
        //         1000e6
        //     );

        PositionConfig memory config = PositionConfig({ poolKey: key, tickLower: -60, tickUpper: 60 });

        mint(config, 1000e6, address(this), "");

        uint256 tokenId_ = 1;

        lpm.subscribe(tokenId_, config, address(wMHook));

        // Check ownership of NFT
        assertEq(IERC721Like(address(lpm)).ownerOf(tokenId_), address(this));
    }

    function test_increaseLiquidity() public {
        PositionConfig memory config = PositionConfig({ poolKey: key, tickLower: -60, tickUpper: 60 });

        mint(config, 1000e6, address(this), "");

        increaseLiquidity(1, config, 50e6, "");
    }

    function test_decreaseLiquidity() public {
        PositionConfig memory config = PositionConfig({ poolKey: key, tickLower: -60, tickUpper: 60 });

        mint(config, 1000e6, address(this), "");

        decreaseLiquidity(1, config, 50e6, "");
    }
}
