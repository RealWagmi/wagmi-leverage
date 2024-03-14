// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { LiquidityBorrowingManager } from "contracts/LiquidityBorrowingManager.sol";
import { FlashLoanAggregator } from "contracts/FlashLoanAggregator.sol";
import { LightQuoterV3 } from "contracts/LightQuoterV3.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";
import { INonfungiblePositionManager } from "contracts/interfaces/INonfungiblePositionManager.sol";

import { ApproveSwapAndPay } from "contracts/abstract/ApproveSwapAndPay.sol";

import { LiquidityManager } from "contracts/abstract/LiquidityManager.sol";
import { IApproveSwapAndPay, ILiquidityManager, ILiquidityBorrowingManager } from "contracts/interfaces/ILiquidityBorrowingManager.sol";

import { TickMath } from "../../contracts/vendor0.8/uniswap/TickMath.sol";
import { LiquidityAmounts } from "../../contracts/vendor0.8/uniswap/LiquidityAmounts.sol";
import { Constants } from "../../contracts/libraries/Constants.sol";

import { console } from "forge-std/console.sol";

contract SimpleBorrowRepayMetis is Test, HelperContract {
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02;
    address constant UNISWAP_V3_FACTORY = 0x8112E18a34b63964388a3B2984037d6a2EFE5B8A;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    address constant alice = 0xcD28C364Fd3163f2DF2Bf89c6D5A897477EB1e33; // 0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8 jordge
    address constant WAGMI = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7;
    address constant USDT = 0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC;
    address constant WMETIS = 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481;
    address constant AAVE_POOL_ADDRESS_PROVIDER = 0xB9FABd7500B2C6781c35Dd48d54f81fc2299D7AF;
    LiquidityBorrowingManager borrowingManager;

    function setUp() public {
        vm.createSelectFork("metis", 14484957);
        vm.label(address(WAGMI), "WAGMI");
        vm.label(address(WMETIS), "WMETIS");
        vm.label(address(USDT), "USDT");
        vm.label(address(this), "SimpleBorrowRepayMetis");
        vm.label(address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS), "NONFUNGIBLE_POSITION_MANAGER");
        deal(address(WMETIS), alice, 100_000_000e18);
        address lightQuoter = address(new LightQuoterV3());
        FlashLoanAggregator flashLoanAggregator = new FlashLoanAggregator(
            AAVE_POOL_ADDRESS_PROVIDER,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH,
            "wagmi"
        );
        borrowingManager = new LiquidityBorrowingManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            address(flashLoanAggregator),
            lightQuoter,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        borrowingManager.setSwapCallToWhitelist(
            0x8B741B0D79BE80E135C880F7583d427B4D41F015,
            0x04e45aaf,
            true
        ); //exactInputSingle
        borrowingManager.setSwapCallToWhitelist(
            0x8B741B0D79BE80E135C880F7583d427B4D41F015,
            0xb858183f,
            true
        ); //exactInput
        //Open Ocean Exchange Proxy
        borrowingManager.setSwapCallToWhitelist(
            0x6352a56caadC4F1E25CD6c75970Fa768A3304e64,
            0x90411a32,
            true
        ); //swap
        vm.label(address(borrowingManager), "LiquidityBorrowingManager");
        vm.label(lightQuoter, "LightQuoterV3");
        vm.label(borrowingManager.VAULT_ADDRESS(), "Vault");
        vm.label(alice, "Alice");
    }

    function test_SimpleBorrowRepay() public {
        uint256 tokenId = 183;
        address ownerPositionManager = INonfungiblePositionManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        ).ownerOf(tokenId);
        vm.startPrank(ownerPositionManager);

        INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER_ADDRESS).approve(
            address(borrowingManager),
            tokenId
        );
        vm.stopPrank();
        vm.startPrank(alice);
        _maxApproveIfNecessary(address(WMETIS), address(borrowingManager), type(uint256).max);

        ILiquidityManager.LoanInfo memory loanInfo = ILiquidityManager.LoanInfo({
            liquidity: 90177335165481605,
            tokenId: tokenId
        });

        IApproveSwapAndPay.SwapParams[] memory swapParams;

        LiquidityManager.LoanInfo[] memory loanInfoArrayMemory = new LiquidityManager.LoanInfo[](1);
        loanInfoArrayMemory[0] = loanInfo;

        LiquidityBorrowingManager.BorrowParams
            memory AliceBorrowingParams = ILiquidityBorrowingManager.BorrowParams({
                internalSwapPoolfee: 1500,
                saleToken: address(USDT),
                holdToken: address(WMETIS),
                minHoldTokenOut: 841937399665370526001,
                maxMarginDeposit: type(uint256).max,
                maxDailyRate: 2564671424041240532,
                externalSwap: swapParams,
                loans: loanInfoArrayMemory
            });

        borrowingManager.borrow(AliceBorrowingParams, block.timestamp + 60);
        bytes32[] memory AliceBorrowingKeys = borrowingManager.getBorrowingKeysForBorrower(
            address(alice)
        );
        vm.roll(block.number + 10);

        ILiquidityManager.FlashLoanRoutes memory routes;

        LiquidityBorrowingManager.RepayParams
            memory AliceRepayingParams = ILiquidityBorrowingManager.RepayParams({
                isEmergency: false,
                routes: routes,
                borrowingKey: AliceBorrowingKeys[0],
                minHoldTokenOut: 0,
                minSaleTokenOut: 0
            });
        borrowingManager.repay(AliceRepayingParams, block.timestamp + 60);

        vm.stopPrank();
    }
}
