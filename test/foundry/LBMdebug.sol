// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import { LiquidityBorrowingManager } from "contracts/LiquidityBorrowingManager.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";
import { IApproveSwapAndPay, ILiquidityManager, ILiquidityBorrowingManager } from "contracts/interfaces/ILiquidityBorrowingManager.sol";
import { console } from "forge-std/console.sol";

contract LBMdebug is Test, HelperContract {
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02;
    address constant UNISWAP_V3_FACTORY = 0x8112E18a34b63964388a3B2984037d6a2EFE5B8A;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    LiquidityBorrowingManager constant lbm =
        LiquidityBorrowingManager(0x20fa274D00fF4917A13cD464FDbB200475B6EaBd);
    address constant alice = 0xF00c8aE29f49173C976e0926aaB71931cd646cFA;
    address constant POOL = 0x28D5576057A27F95d5dB75776BA50e6e84FAf477;
    address constant WMETIS = 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481;
    address constant WAGMI = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7;

    function setUp() public {
        vm.createSelectFork("metis", 14674550);
        vm.label(address(this), "ChartDebug");
        vm.label(address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS), "NONFUNGIBLE_POSITION_MANAGER");
        vm.label(address(lbm), "LiquidityBorrowingManager");
        vm.label(alice, "Alice");
        vm.label(lbm.VAULT_ADDRESS(), "Vault");
        vm.label(POOL, "WMETIS/WAGMI UNI-V3 Pool");
        vm.label(WMETIS, "WMETIS");
        vm.label(WAGMI, "WAGMI");
    }

    function test_lbm() public {
        vm.startPrank(alice);

        ILiquidityManager.FlashLoanRoutes memory routes;

        LiquidityBorrowingManager.RepayParams
            memory AliceRepayingParams = ILiquidityBorrowingManager.RepayParams({
                isEmergency: false,
                routes: routes,
                borrowingKey: 0x2d11cb4b77da73cf39de42bd92c3bad7b29f58dfa82098c7b57f7e279f51d1c8,
                minHoldTokenOut: 0,
                minSaleTokenOut: 0
            });

        lbm.repay(AliceRepayingParams, block.timestamp + 1);

        vm.stopPrank();
    }
}
