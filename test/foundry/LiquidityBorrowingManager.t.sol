// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { LiquidityBorrowingManager } from "contracts/LiquidityBorrowingManager.sol";
import { AggregatorMock } from "contracts/mock/AggregatorMock.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";
import { INonfungiblePositionManager } from "contracts/interfaces/INonfungiblePositionManager.sol";

contract ContractTest is Test, HelperContract {
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV3Pool WBTC_WETH_500_POOL = IUniswapV3Pool(0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0);
    IUniswapV3Pool WETH_USDT_500_POOL = IUniswapV3Pool(0x11b815efB8f581194ae79006d24E0d814B7697F6);
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant UNISWAP_V3_QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    address constant alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    AggregatorMock aggregatorMock;
    LiquidityBorrowingManager borrowingManager;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_329_500);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDT), "USDT");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(WBTC_WETH_500_POOL), "WBTC_WETH_500_POOL");
        vm.label(address(WETH_USDT_500_POOL), "WETH_USDT_500_POOL");
        vm.label(address(this), "ContractTest");
        aggregatorMock = new AggregatorMock(UNISWAP_V3_QUOTER_V2);
        borrowingManager = new LiquidityBorrowingManager(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            UNISWAP_V3_QUOTER_V2,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        vm.label(address(borrowingManager), "LiquidityBorrowingManager");
        vm.label(address(aggregatorMock), "AggregatorMock");
        deal(address(USDT), address(this), 1000000000e6);
        deal(address(WBTC), address(this), 10e8);
        deal(address(WETH), address(this), 100e18);

        _maxApproveIfNecessary(address(WBTC), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(WETH), address(borrowingManager), type(uint256).max);
        _maxApproveIfNecessary(address(USDT), address(borrowingManager), type(uint256).max);

        _maxApproveIfNecessary(
            address(WBTC),
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            type(uint256).max
        );
        _maxApproveIfNecessary(
            address(WETH),
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            type(uint256).max
        );
        _maxApproveIfNecessary(
            address(USDT),
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            type(uint256).max
        );
    }

    function test_SetUpState() public {
        assertEq(WBTC_WETH_500_POOL.token0(), address(WBTC));
        assertEq(WBTC_WETH_500_POOL.token1(), address(WETH));
        assertEq(WETH_USDT_500_POOL.token0(), address(WETH));
        assertEq(WETH_USDT_500_POOL.token1(), address(USDT));
        assertEq(USDT.balanceOf(address(this)), 1000000000e6);
        assertEq(WBTC.balanceOf(address(this)), 10e8);
        assertEq(WETH.balanceOf(address(this)), 100e18);
        assertEq(borrowingManager.owner(), address(this));
        assertEq(borrowingManager.dailyRateOperator(), address(this));
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
}
