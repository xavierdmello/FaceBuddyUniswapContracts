// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {FaceBuddy} from "../src/FaceBuddy.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";

contract FaceBuddyTest is Test {
    FaceBuddy public faceBuddy;
    uint256 mainnetFork;

    // Unichain mainnet addresses (checksummed)
    address constant UNIVERSAL_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address constant POOL_MANAGER = 0x70d04384b5C3A466ec7fF682e7C8e9185AED9932;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public {
        // Create and select fork
        mainnetFork = vm.createFork("https://unichain-mainnet.g.alchemy.com/v2/cCmdllUM3oiBjOpStn0RrTb8eifa87te");
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
} 