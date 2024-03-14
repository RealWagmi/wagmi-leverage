// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Pool } from "contracts/interfaces/IUniswapV3Pool.sol";
import { LiquidityBorrowingManager } from "contracts/LiquidityBorrowingManager.sol";
import { FlashLoanAggregator } from "contracts/FlashLoanAggregator.sol";
import { LightQuoterV3 } from "contracts/LightQuoterV3.sol";
import { AggregatorMock } from "contracts/mock/AggregatorMock.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";
import { INonfungiblePositionManager } from "contracts/interfaces/INonfungiblePositionManager.sol";
import { IApproveSwapAndPay, ILiquidityManager, ILiquidityBorrowingManager } from "contracts/interfaces/ILiquidityBorrowingManager.sol";
import { ApproveSwapAndPay } from "contracts/abstract/ApproveSwapAndPay.sol";

import { LiquidityManager } from "contracts/abstract/LiquidityManager.sol";

import { TickMath } from "../../contracts/vendor0.8/uniswap/TickMath.sol";
import { LiquidityAmounts } from "../../contracts/vendor0.8/uniswap/LiquidityAmounts.sol";
import { Constants } from "../../contracts/libraries/Constants.sol";

import { console } from "forge-std/console.sol";

contract ContractTest is Test, HelperContract {
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV3Pool WBTC_WETH_500_POOL = IUniswapV3Pool(0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0);
    IUniswapV3Pool WETH_USDT_500_POOL = IUniswapV3Pool(0x11b815efB8f581194ae79006d24E0d814B7697F6);
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant UNISWAP_V3_QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address constant LIGHT_QUOTER_V3 = 0xbd352897CF946E205C80520976F6573b7FF3a734;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant AAVE_POOL_ADDRESS_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    AggregatorMock aggregatorMock;
    LiquidityBorrowingManager borrowingManager;
    LightQuoterV3 lightQuoterV3;

    uint256 tokenId;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_329_500);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDT), "USDT");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(WBTC_WETH_500_POOL), "WBTC_WETH_500_POOL");
        vm.label(address(WETH_USDT_500_POOL), "WETH_USDT_500_POOL");
        vm.label(address(this), "ContractTest");

        aggregatorMock = new AggregatorMock(UNISWAP_V3_QUOTER_V2);
        lightQuoterV3 = new LightQuoterV3();
        FlashLoanAggregator flashLoanAggregator = new FlashLoanAggregator(
            AAVE_POOL_ADDRESS_PROVIDER,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH,
            "uniswap"
        );
        borrowingManager = new LiquidityBorrowingManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            address(flashLoanAggregator),
            address(lightQuoterV3),
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        flashLoanAggregator.setWagmiLeverageAddress(address(borrowingManager));
        vm.label(address(lightQuoterV3), "LIGHT_QUOTER_V3");
        vm.label(address(borrowingManager), "LiquidityBorrowingManager");
        vm.label(address(aggregatorMock), "AggregatorMock");
        vm.label(address(flashLoanAggregator), "FlashLoanAggregator");
        deal(address(USDT), address(this), 1_000_000_000e6);
        deal(address(WBTC), address(this), 10e8);
        deal(address(WETH), address(this), 100e18);
        deal(address(USDT), alice, 1_000_000_000_000_000_000_000_000e6);
        deal(address(WBTC), alice, 1000e8);
        deal(address(WETH), alice, 100_000_000_000_000_000e18);

        deal(address(USDT), bob, 1_000_000_000e6);
        deal(address(WBTC), bob, 1000e8);
        deal(address(WETH), bob, 10_000e18);
        //deal eth to alice
        deal(alice, 10_000 ether);
        deal(bob, 1000 ether);

        // deal(address(USDT), address(borrowingManager), 1000000000e6);
        // deal(address(WBTC), address(borrowingManager), 10e8);
        // deal(address(WETH), address(borrowingManager), 100e18);

        _maxApproveIfNecessary(address(WBTC), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(WETH), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(USDT), address(borrowingManager), type(uint256).max);

        vm.startPrank(alice);
        _maxApproveIfNecessary(address(WBTC), address(borrowingManager), type(uint256).max);
        // _maxApproveIfNecessary(address(WETH), address(borrowingManager), type(uint256).max);
        IERC20(address(WETH)).approve(address(borrowingManager), type(uint256).max);
        IERC20(address(WBTC)).approve(address(borrowingManager), type(uint256).max);
        IERC20(address(WETH)).approve(
            address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS),
            type(uint256).max
        );
        IERC20(address(WBTC)).approve(
            address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS),
            type(uint256).max
        );
        _maxApproveIfNecessary(address(USDT), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(WBTC), address(this), type(uint256).max);
        _maxApproveIfNecessary(address(WETH), address(this), type(uint256).max);
        _maxApproveIfNecessary(address(USDT), address(this), type(uint256).max);

        // _maxApproveIfNecessary(
        //     address(WBTC),
        //     NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        //     type(uint256).max
        // );
        // _maxApproveIfNecessary(
        //     address(WETH),
        //     NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        //     type(uint256).max
        // );
        _maxApproveIfNecessary(
            address(USDT),
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            type(uint256).max
        );

        (tokenId, , , ) = mintPositionAndApprove();
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(address(WETH)).approve(address(borrowingManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(borrowingManager));
        IERC20(address(WETH)).approve(
            address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS),
            type(uint256).max
        );
        IERC20(address(WBTC)).approve(
            address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(WBTC_WETH_500_POOL.token0(), address(WBTC));
        assertEq(WBTC_WETH_500_POOL.token1(), address(WETH));
        assertEq(WETH_USDT_500_POOL.token0(), address(WETH));
        assertEq(WETH_USDT_500_POOL.token1(), address(USDT));
        assertEq(USDT.balanceOf(address(this)), 1_000_000_000e6);
        assertEq(WBTC.balanceOf(address(this)), 10e8);
        assertEq(WETH.balanceOf(address(this)), 100e18);
        assertEq(borrowingManager.owner(), address(this));
        assertEq(borrowingManager.operator(), address(this));
        assertEq(
            borrowingManager.computePoolAddress(address(USDT), address(WETH), 500),
            address(WETH_USDT_500_POOL)
        );
        assertEq(
            borrowingManager.computePoolAddress(address(WBTC), address(WETH), 500),
            address(WBTC_WETH_500_POOL)
        );
        assertEq(
            address(borrowingManager.underlyingPositionManager()),
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        );
    }

    ILiquidityManager.LoanInfo[] loans;

    function createBorrowParams(
        uint256 _tokenId,
        uint128 liquidity
    ) public returns (LiquidityBorrowingManager.BorrowParams memory borrow) {
        ILiquidityManager.LoanInfo memory loanInfo = ILiquidityManager.LoanInfo({
            liquidity: liquidity,
            tokenId: _tokenId //5500 = 1319241402 500 = 119931036 10 = 2398620
        });

        loans.push(loanInfo);

        LiquidityManager.LoanInfo[] memory loanInfoArrayMemory = loans;
        IApproveSwapAndPay.SwapParams[] memory swapParams;
        //  bytes memory swapData = "";
        // new ApproveSwapAndPay.SwapParams[](1);
        // swapParams[0] = IApproveSwapAndPay.SwapParams({
        //     swapTarget: address(0),
        //     maxGasForCall: 0,
        //     swapData: swapData
        // });

        borrow = ILiquidityBorrowingManager.BorrowParams({
            internalSwapPoolfee: 500,
            saleToken: address(WBTC), //token1 - WETH
            holdToken: address(WETH), //token0 - WBTC
            minHoldTokenOut: 1,
            maxMarginDeposit: 1e18,
            maxDailyRate: 0,
            externalSwap: swapParams,
            loans: loanInfoArrayMemory
        });
        borrow.maxDailyRate = (borrowingManager.getHoldTokenInfo(address(WBTC), address(WETH)))
            .currentDailyRate;
    }

    function _minimumLiquidityAmt(
        int24 tickLower,
        int24 tickUpper
    ) private pure returns (uint128 minLiquidity) {
        uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickUpper - 1),
            TickMath.getSqrtRatioAtTick(tickUpper),
            Constants.MINIMUM_EXTRACTED_AMOUNT
        );
        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickLower + 1),
            Constants.MINIMUM_EXTRACTED_AMOUNT
        );
        minLiquidity = liquidity0 > liquidity1 ? liquidity0 : liquidity1;
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

    function mintPositionAndApprove()
        public
        returns (uint256 _tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager
            .MintParams({
                token0: address(WBTC),
                token1: address(WETH),
                fee: 3000,
                tickLower: 253_320, //TickMath.MIN_TICK,
                tickUpper: 264_600, //TickMath.MAX_TICK ,
                amount0Desired: 1e7,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 60
            });
        (_tokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        ).mint{ value: 1 ether }(mintParams);
        INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER_ADDRESS).approve(
            address(borrowingManager),
            _tokenId
        );
    }

    function test_MinimumLiquiditeAmount() public {
        vm.startPrank(bob);
        uint128 minLiqAmt = _minimumLiquidityAmt(253_320, 264_600);
        // console.log("minimumLiquidityAmt=", minLiqAmt);

        LiquidityBorrowingManager.BorrowParams memory BobBorrowingParams = createBorrowParams(
            tokenId,
            minLiqAmt
        );

        borrowingManager.borrow(BobBorrowingParams, block.timestamp + 60);
        bytes32[] memory BobBorrowingKeys = borrowingManager.getBorrowingKeysForBorrower(
            address(bob)
        );

        LiquidityBorrowingManager.RepayParams memory BobRepayingParams = createRepayParams(
            BobBorrowingKeys[0]
        );
        borrowingManager.repay(BobRepayingParams, block.timestamp + 60);

        BobBorrowingParams = createBorrowParams(tokenId, 1000);
        vm.expectRevert();
        borrowingManager.borrow(BobBorrowingParams, block.timestamp + 60);

        vm.stopPrank();
    }

    function testBorrowExtended() public {
        uint128 minLiqAmt = _minimumLiquidityAmt(253_320, 264_600);

        address vault = borrowingManager.VAULT_ADDRESS();
        console.log("initial WETH blance bob", WETH.balanceOf(bob));
        console.log("initial WBTC blance bob", WBTC.balanceOf(bob));
        console.log("initial WETH blance vault", WETH.balanceOf(vault));
        console.log("initial WBTC blance vault", WBTC.balanceOf(vault));
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        ).positions(tokenId);
        console.log("initial lender liquidity", liquidity);

        vm.startPrank(bob);
        borrowingManager.borrow(createBorrowParams(tokenId, minLiqAmt), block.timestamp + 1);
        bytes32[] memory key = borrowingManager.getBorrowingKeysForTokenId(tokenId);

        borrowingManager.borrow(createBorrowParams(tokenId, minLiqAmt), block.timestamp + 1);

        borrowingManager.borrow(createBorrowParams(tokenId, minLiqAmt), block.timestamp + 1);

        borrowingManager.borrow(createBorrowParams(tokenId, minLiqAmt), block.timestamp + 1);

        //  repay tokens

        uint24 poolfeeTiers = 500;
        uint256 dexIndx = 0;
        address secondToken = address(WETH);

        ILiquidityManager.FlashLoanParams[]
            memory flashLoanParams = new ILiquidityManager.FlashLoanParams[](1);
        flashLoanParams[0] = ILiquidityManager.FlashLoanParams({
            protocol: 1, //uniswap
            data: abi.encode(poolfeeTiers, secondToken, dexIndx)
        });

        ILiquidityManager.FlashLoanRoutes memory routes = ILiquidityManager.FlashLoanRoutes({
            strict: true,
            flashLoanParams: flashLoanParams
        });
        LiquidityBorrowingManager.RepayParams memory params = createRepayParams(key[0]);
        params.routes = routes;
        (uint saleOut, uint holdToken) = borrowingManager.repay(params, block.timestamp + 1);
        vm.stopPrank();

        console.log("saleTokenOut", saleOut);
        console.log("holdTokenOut", holdToken);
        console.log("WETH balance bob after repayment", WETH.balanceOf(bob));
        console.log("WBTC balance bob after repayment", WBTC.balanceOf(bob));
        console.log("WETH balance vault after repayment", WETH.balanceOf(vault));
        console.log("WBTC balance vault after repayment", WBTC.balanceOf(vault));
        (, , , , , , , liquidity, , , , ) = INonfungiblePositionManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        ).positions(tokenId);
        console.log("lender liquidity after repayment", liquidity);
    }
}
