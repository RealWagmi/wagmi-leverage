// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

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

contract SimpleBorrowRepayKava is Test, HelperContract {
    IERC20 USDT = IERC20(0x919C1c267BC06a7039e03fcc2eF738525769109c);
    IERC20 ODIN = IERC20(0x851feE47C6588506277c439A7526aE58cD1d15e5);
    // wagmi kava
    // https://github.com/RealWagmi/v3_core
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xa9aF508A15fc3B75763A9e536505FFE1F884D12C;
    address constant UNISWAP_V3_FACTORY = 0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B;
    address constant LIGHT_QUOTER_V3 = 0xbd352897CF946E205C80520976F6573b7FF3a734;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    address constant alice = 0x1D8D3417d1d41AAc899A43C3592eAfC504634171;
    address constant AAVE_POOL_ADDRESS_PROVIDER = address(0);
    // LiquidityBorrowingManager borrowingManager;

    uint256 roundingUpTestFork;
    uint256 calculateAmountsToSwapTestFork;

    function setUp() public {
        roundingUpTestFork = vm.createFork("kava", 8367114);
        calculateAmountsToSwapTestFork = vm.createFork("kava", 8394603);
        vm.label(address(USDT), "USDt");
        vm.label(address(ODIN), "ODIN");
        vm.label(address(this), "SimpleBorrowRepayKava");
        vm.label(address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS), "NONFUNGIBLE_POSITION_MANAGER");
        vm.label(alice, "Alice");
    }

    ILiquidityManager.LoanInfo[] loans;

    function createBorrowParams(
        uint24 internalSwapPoolfee,
        address saleToken,
        address holdToken,
        uint256 minHoldTokenOut,
        uint256 maxMarginDeposit,
        uint256 maxDailyRate,
        uint128 liquidity,
        uint256 _tokenId
    ) public returns (LiquidityBorrowingManager.BorrowParams memory borrow) {
        ILiquidityManager.LoanInfo memory loanInfo = ILiquidityManager.LoanInfo({
            liquidity: liquidity,
            tokenId: _tokenId
        });

        loans.push(loanInfo);

        IApproveSwapAndPay.SwapParams[] memory swapParams;
        // bytes memory swapData = "";
        //  = new ApproveSwapAndPay.SwapParams[](1);
        // SwapParams[0] = IApproveSwapAndPay.SwapParams({
        //     swapTarget: address(0),
        //     maxGasForCall: 0,
        //     swapData: swapData
        // });

        LiquidityManager.LoanInfo[] memory loanInfoArrayMemory = loans;

        borrow = ILiquidityBorrowingManager.BorrowParams({
            internalSwapPoolfee: internalSwapPoolfee,
            saleToken: saleToken,
            holdToken: holdToken,
            minHoldTokenOut: minHoldTokenOut,
            maxMarginDeposit: maxMarginDeposit,
            maxDailyRate: maxDailyRate,
            externalSwap: swapParams,
            loans: loanInfoArrayMemory
        });
    }

    function createRepayParams(
        bytes32 _borrowingKey
    ) public pure returns (LiquidityBorrowingManager.RepayParams memory repay) {
        ILiquidityManager.FlashLoanRoutes memory routes;

        repay = ILiquidityBorrowingManager.RepayParams({
            isEmergency: false,
            routes: routes,
            borrowingKey: _borrowingKey,
            minHoldTokenOut: 0,
            minSaleTokenOut: 0
        });
    }

    function test_AmountsRoundingUpKava() public {
        vm.selectFork(roundingUpTestFork);
        address lightQuoter = address(new LightQuoterV3());
        FlashLoanAggregator flashLoanAggregator = new FlashLoanAggregator(
            AAVE_POOL_ADDRESS_PROVIDER,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH,
            "wagmi"
        );
        LiquidityBorrowingManager borrowingManager = new LiquidityBorrowingManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            address(flashLoanAggregator),
            lightQuoter,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        vm.label(address(borrowingManager), "LiquidityBorrowingManager");
        vm.startPrank(alice);

        INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER_ADDRESS).approve(
            address(borrowingManager),
            371
        );
        _maxApproveIfNecessary(address(USDT), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(ODIN), address(borrowingManager), type(uint256).max);

        LiquidityBorrowingManager.BorrowParams memory AliceBorrowingParams = createBorrowParams(
            uint24(10000),
            address(USDT),
            address(ODIN),
            99502487562189054726,
            type(uint256).max,
            108537896990498585,
            76304477072925,
            371
        );

        borrowingManager.borrow(AliceBorrowingParams, block.timestamp + 60);
        bytes32[] memory AliceBorrowingKeys = borrowingManager.getBorrowingKeysForBorrower(
            address(alice)
        );
        vm.roll(block.number + 10);

        LiquidityBorrowingManager.RepayParams memory AliceRepayingParams = createRepayParams(
            AliceBorrowingKeys[0]
        );
        borrowingManager.repay(AliceRepayingParams, block.timestamp + 60);

        vm.stopPrank();
    }

    function test_CalculateZapOutKava() public {
        vm.selectFork(calculateAmountsToSwapTestFork);
        address lightQuoter = address(new LightQuoterV3());
        FlashLoanAggregator flashLoanAggregator = new FlashLoanAggregator(
            AAVE_POOL_ADDRESS_PROVIDER,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH,
            "wagmi"
        );
        LiquidityBorrowingManager borrowingManager = new LiquidityBorrowingManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            address(flashLoanAggregator),
            lightQuoter,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        vm.label(address(borrowingManager), "LiquidityBorrowingManager");
        vm.label(lightQuoter, "LightQuoterV3");
        vm.label(borrowingManager.VAULT_ADDRESS(), "Vault");

        address ownerPositionManager = INonfungiblePositionManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        ).ownerOf(384);
        vm.startPrank(ownerPositionManager);

        INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER_ADDRESS).approve(
            address(borrowingManager),
            384
        );
        vm.stopPrank();
        vm.startPrank(alice);
        _maxApproveIfNecessary(address(USDT), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(ODIN), address(borrowingManager), type(uint256).max);

        LiquidityBorrowingManager.BorrowParams memory AliceBorrowingParams = createBorrowParams(
            uint24(10000),
            address(USDT),
            address(ODIN),
            1492537313432835820895,
            type(uint256).max,
            1536828855480484849,
            1011284991173027,
            384
        );

        borrowingManager.borrow(AliceBorrowingParams, block.timestamp + 60);
        bytes32[] memory AliceBorrowingKeys = borrowingManager.getBorrowingKeysForBorrower(
            address(alice)
        );

        LiquidityBorrowingManager.RepayParams memory AliceRepayingParams = createRepayParams(
            AliceBorrowingKeys[0]
        );
        borrowingManager.repay(AliceRepayingParams, block.timestamp + 60);

        vm.stopPrank();
    }
}
