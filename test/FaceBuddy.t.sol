// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {FaceBuddy} from "../src/FaceBuddy.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "@forge-std/StdCheats.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {console} from "forge-std/console.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

contract FaceBuddyTest is Test {
    FaceBuddy public faceBuddy;
    uint256 mainnetFork;
    string RPC_URL;
    // using PoolIdLibrary for PoolKey global;

    // Add receive function to accept ETH
    receive() external payable {}
    
    // Unichain mainnet addresses (loaded from env)
    address UNIVERSAL_ROUTER;
    address POOL_MANAGER;
    address PERMIT2;
 
    address USDC;

    function setUp() public {
        // Load environment variables
        RPC_URL = vm.envString("RPC_URL");
        UNIVERSAL_ROUTER = vm.envAddress("UNIVERSAL_ROUTER");
        POOL_MANAGER = vm.envAddress("POOL_MANAGER");
        PERMIT2 = vm.envAddress("PERMIT2");

        USDC = vm.envAddress("USDC");

        // Create and select fork
        mainnetFork = vm.createFork(RPC_URL);
        vm.selectFork(mainnetFork);
        
        // Verify we're on Unichain
        assertEq(block.chainid, 130);

        // Deploy FaceBuddy
        faceBuddy = new FaceBuddy(
            payable(UNIVERSAL_ROUTER),
            POOL_MANAGER,
            PERMIT2
        );
    }

    function testDeployment() public {
        // Verify constructor parameters were set correctly
        assertEq(address(faceBuddy.router()), UNIVERSAL_ROUTER);
        assertEq(address(faceBuddy.poolManager()), POOL_MANAGER);
        assertEq(address(faceBuddy.permit2()), PERMIT2);

        // Log deployment information
        console2.log("FaceBuddy deployed at:", address(faceBuddy));
        console2.log("Block number:", block.number);
        console2.log("Chain ID:", block.chainid);
    }

    function testMintETH() public {
        StdCheats.deal(address(this), 10 ether);
        assertEq(address(this).balance, 10 ether);
    }

    function testMintUSDC() public {
        // Mint to the test contract address instead of msg.sender
        StdCheats.deal(USDC, address(this), 1000000); // 1 USDC = 1e6 units
        assertEq(IERC20(USDC).balanceOf(address(this)), 1000000);
    }

    function testSwapETH() public payable {
        // Mint ETH
        testMintETH();
        console.log("USDC balance before swap:", IERC20(USDC).balanceOf(address(this)));
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),  // ETH
            currency1: Currency.wrap(USDC),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        
        bytes32 poolId = PoolId.unwrap(key.toId());
        console.logBytes32(poolId);

        // Send value with the transaction
        faceBuddy.swapExactInputSingle{value: 1 ether}(
            key, 
            1 ether,
            1000000, 
            block.timestamp + 1 days,
            true
        );
    }

        function testSwapAndSendETHToUSDC() public payable {
        // Mint ETH
        testMintETH();

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),  // ETH
            currency1: Currency.wrap(USDC),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        
        bytes32 poolId = PoolId.unwrap(key.toId());
        console.logBytes32(poolId);
        faceBuddy.setPreferredToken(USDC);
        // Send value with the transaction
        faceBuddy.swapAndSendPreferredToken{value: 1 ether}(
            address(this),
            address(0),
            1 ether,
            key,
            1000000,
            block.timestamp + 1 days
        );
        console.log("USDC balance after swap:", IERC20(USDC).balanceOf(address(this)));

    }

    function testApproveUSDC() public {
        // Approve from the test contract address
        IERC20(USDC).approve(address(faceBuddy), 1000000);
    }

    function testSwapUSDC() public {
        // Mint USDC to this contract
        testMintUSDC();
        testApproveUSDC();
    
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),  // ETH
            currency1: Currency.wrap(USDC),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        
        bytes32 poolId = PoolId.unwrap(key.toId());
        console.logBytes32(poolId);
        
        // Send value with the transaction
        faceBuddy.swapExactInputSingle(
            key, 
            1000000,  // amount of USDC to swap
            1,        // minimum ETH to receive (very low for testing)
            block.timestamp + 1 days,
            false     // false because we're swapping token1 (USDC) for token0 (ETH)
        );
    }

    
} 

