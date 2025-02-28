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
    mapping(address => address) public preferredToken;
    // Add receive function to accept ETH payments
    receive() external payable {}
    
    // Add fallback function as a backup
    fallback() external payable {}

    constructor(address payable _router, address _poolManager, address _permit2) {
        router = UniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    function approveTokenWithPermit2(
    address token,
    uint160 amount,
    uint48 expiration
) internal {
    IERC20(token).approve(address(permit2), type(uint256).max);
    permit2.approve(token, address(router), amount, expiration);
   
}
 function setPreferredToken(address token) external {
    preferredToken[msg.sender] = token;
 }

function swapExactInputSingle(
    PoolKey memory key, // PoolKey struct that identifies the v4 pool
    uint128 amountIn, // Exact amount of tokens to swap
    uint128 minAmountOut, // Minimum amount of output tokens expected
    uint256 deadline, // Timestamp after which the transaction will revert
    bool zeroForOne // true if we're swapping token0 for token1
) public payable {

    // If token0 is ETH and we're swapping token1 to ETH, we need to transfer the token1 and approve it
    if (key.currency0 == Currency.wrap(address(0)) && zeroForOne ==  false) {
        IERC20(Currency.unwrap(key.currency1)).transferFrom(msg.sender, address(this), amountIn);
        approveTokenWithPermit2(Currency.unwrap(key.currency1), amountIn, uint48(block.timestamp + 1 days));
    }

    // If token1 is ETH and we're swapping token0 to ETH, we need to transfer the token0 and approve it
    if (key.currency1 == Currency.wrap(address(0)) && zeroForOne == true) {
        IERC20(Currency.unwrap(key.currency0)).transferFrom(msg.sender, address(this), amountIn);
        approveTokenWithPermit2(Currency.unwrap(key.currency0), amountIn, uint48(block.timestamp + 1 days));
    }

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
            zeroForOne: zeroForOne,            // true if we're swapping token0 for token1
            amountIn: amountIn,          // amount of tokens we're swapping
            amountOutMinimum: minAmountOut, // minimum amount we expect to receive
            hookData: bytes("")             // no hook data needed
        })
    );

    // Second parameter: specify input tokens for the swap
    // encode SETTLE_ALL parameters
    params[1] = abi.encode(
        zeroForOne ? key.currency0 : key.currency1,  // Input token
        amountIn
    );

    // Third parameter: specify output tokens from the swap
    params[2] = abi.encode(
        zeroForOne ? key.currency1 : key.currency0,  // Output token
        minAmountOut
    );

    // Combine actions and params into inputs
    inputs[0] = abi.encode(actions, params);

    // Execute the swap and forward the ETH value
    router.execute{value: msg.value}(commands, inputs, deadline);

    if (!(key.currency1 == Currency.wrap(address(0))) && zeroForOne == true) {
        IERC20(Currency.unwrap(key.currency1)).transfer(msg.sender, IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this)));
    }

    else if (!(key.currency0 == Currency.wrap(address(0))) && zeroForOne == false) {
        IERC20(Currency.unwrap(key.currency0)).transfer(msg.sender, IERC20(Currency.unwrap(key.currency0)).balanceOf(address(this)));
    }

    else {
        payable(msg.sender).transfer(address(this).balance);
    }
}


 function swapAndSendPreferredToken(
    address recipient,
    address inputToken, // USDC address or address(0) for ETH
    uint256 amount,
    PoolKey memory poolKey,
    uint128 minAmountOut,
    uint256 deadline
) external payable {
    require(recipient != address(0), "Invalid recipient");
    require(amount > 0, "Amount must be greater than 0");
    
    // Get recipient's preferred token
    address preferredTokenAddr = preferredToken[recipient];
    
    // If no preference or preference matches input, send directly
    if (preferredTokenAddr == address(0) || preferredTokenAddr == inputToken) {
        if (inputToken == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
            payable(recipient).transfer(amount);
        } else {
            IERC20(inputToken).transferFrom(msg.sender, recipient, amount);
        }
        return;
    }

    // Need to swap - determine swap direction
    bool zeroForOne = poolKey.currency0 == Currency.wrap(inputToken);
    require(
        (zeroForOne && poolKey.currency1 == Currency.wrap(preferredTokenAddr)) ||
        (!zeroForOne && poolKey.currency0 == Currency.wrap(preferredTokenAddr)),
        "Invalid pool for swap"
    );

    // Handle the swap
    swapExactInputSingle(
        poolKey,
        uint128(amount),
        minAmountOut,
        deadline,
        zeroForOne
    );

    // Transfer the swapped tokens to recipient
    if (preferredTokenAddr == address(0)) {
        payable(recipient).transfer(address(this).balance);
    } else {
        IERC20(preferredTokenAddr).transfer(
            recipient,
            IERC20(preferredTokenAddr).balanceOf(address(this))
        );
    }
}



}