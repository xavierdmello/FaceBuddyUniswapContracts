// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UniversalRouter } from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically.
    ///         For native ETH, Currency currency0 = Currency.wrap(address(0));
    Currency currency0;
    /// @notice The higher currency of the pool, sorted numerically
    Currency currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    IHooks hooks;
}

contract Example {
    using StateLibrary for IPoolManager;

    UniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    constructor(address payable _router, address _poolManager, address _permit2) {
        router = UniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    function approveTokenWithPermit2(
    address token,
    uint160 amount,
    uint48 expiration
) external {
    IERC20(token).approve(address(permit2), type(uint256).max);
    permit2.approve(token, address(router), amount, expiration);
}

function swapExactInputSingle(
    PoolKey calldata key, // PoolKey struct that identifies the v4 pool
    uint128 amountIn, // Exact amount of tokens to swap
    uint128 minAmountOut, // Minimum amount of output tokens expected
    uint256 deadline // Timestamp after which the transaction will revert
) external returns (uint256 amountOut) {
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
}
}