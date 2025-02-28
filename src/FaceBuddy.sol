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
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";

contract FaceBuddy {
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
    PoolKey memory key, // PoolKey struct that identifies the v4 pool
    uint128 amountIn, // Exact amount of tokens to swap
    uint128 minAmountOut, // Minimum amount of output tokens expected
    uint256 deadline // Timestamp after which the transaction will revert
) external {
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
bytes[] memory inputs = new bytes[](1);
    // Encode V4Router actions
bytes memory actions = abi.encodePacked(
    uint8(Actions.SWAP_EXACT_IN_SINGLE),
    uint8(Actions.SETTLE_ALL),
    uint8(Actions.TAKE_ALL)
);

bytes[] memory params = new bytes[](3);

// First parameter: swap configuration
params[0] = abi.encode(
    IV4Router.ExactInputSingleParams({
        poolKey: key,
        zeroForOne: true,            // true if we're swapping token0 for token1
        amountIn: amountIn,          // amount of tokens we're swapping
        amountOutMinimum: minAmountOut, // minimum amount we expect to receive
        hookData: bytes("")             // no hook data needed
    })
);

// Second parameter: specify input tokens for the swap
// encode SETTLE_ALL parameters
params[1] = abi.encode(key.currency0, amountIn);

// Third parameter: specify output tokens from the swap
params[2] = abi.encode(key.currency1, minAmountOut);

// Combine actions and params into inputs
inputs[0] = abi.encode(actions, params);

// Execute the swap
router.execute(commands, inputs, deadline);
}


}