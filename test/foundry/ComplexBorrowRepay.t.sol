// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { LiquidityBorrowingManager } from "contracts/LiquidityBorrowingManager.sol";
import { FlashLoanAggregator } from "contracts/FlashLoanAggregator.sol";
import { LightQuoterV3 } from "contracts/LightQuoterV3.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";
import { INonfungiblePositionManager } from "contracts/interfaces/INonfungiblePositionManager.sol";
import { LiquidityManager } from "contracts/abstract/LiquidityManager.sol";
import { IApproveSwapAndPay, ILiquidityManager, ILiquidityBorrowingManager } from "contracts/interfaces/ILiquidityBorrowingManager.sol";
import { TransferHelper } from "contracts/libraries/TransferHelper.sol";

import { console } from "forge-std/console.sol";

contract ComplexBorrowRepay is Test, HelperContract {
    using TransferHelper for address;
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02;
    address constant UNISWAP_V3_FACTORY = 0x8112E18a34b63964388a3B2984037d6a2EFE5B8A;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    address constant alice = 0x0FAB28472D94737c63856033Fd7B936EbB9050A4;
    address constant WAGMI = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7;
    address constant USDT = 0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC;
    address constant AAVE_POOL_ADDRESS_PROVIDER = 0xB9FABd7500B2C6781c35Dd48d54f81fc2299D7AF;
    LiquidityBorrowingManager borrowingManager;
    FlashLoanAggregator flashLoanAggregator;

    function setUp() public {
        vm.createSelectFork("metis", 13428428);
        vm.label(address(WAGMI), "WAGMI");
        vm.label(address(USDT), "USDT");
        vm.label(address(this), "ComplexBorrowRepay");
        vm.label(address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS), "NONFUNGIBLE_POSITION_MANAGER");
        deal(address(WAGMI), alice, 100_000_000e18);
        address lightQuoter = address(new LightQuoterV3());
        flashLoanAggregator = new FlashLoanAggregator(
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
        flashLoanAggregator.setWagmiLeverageAddress(address(borrowingManager));
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

    function test_ComplexBorrowRepay() public {
        uint256 tokenId = 143;
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
        _maxApproveIfNecessary(address(WAGMI), address(borrowingManager), type(uint256).max);

        ILiquidityManager.LoanInfo memory loanInfo = ILiquidityManager.LoanInfo({
            liquidity: 138953943293338389,
            tokenId: tokenId
        });

        IApproveSwapAndPay.SwapParams[] memory exSwapParams = new IApproveSwapAndPay.SwapParams[](
            2
        );
        bytes
            memory data = hex"b858183f000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000800000000000000000000000001bbce9fc68e47cd3e4b6bc3be64e271bcdb3edf1000000000000000000000000000000000000000000000000000000003fd709bd000000000000000000000000000000000000000000000edc167dec7b74e8dbc00000000000000000000000000000000000000000000000000000000000000042bb06dca3ae6887fabf931640f67cab3e3a16f4dc0005dc75cb093e4d61d2a2e65d8e0bbb01de8d89b53481002710af20f5f19698f1d19351028cd7103b63d30de7d7000000000000000000000000000000000000000000000000000000000000";
        exSwapParams[0] = IApproveSwapAndPay.SwapParams({
            swapTarget: 0x8B741B0D79BE80E135C880F7583d427B4D41F015,
            maxGasForCall: 0,
            swapData: data
        });
        data = hex"b858183f000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000800000000000000000000000001bbce9fc68e47cd3e4b6bc3be64e271bcdb3edf100000000000000000000000000000000000000000000000000000000035c28ef0000000000000000000000000000000000000000000000c99c67f89cfe3c43370000000000000000000000000000000000000000000000000000000000000059bb06dca3ae6887fabf931640f67cab3e3a16f4dc0005dc420000000000000000000000000000000000000a0005dc75cb093e4d61d2a2e65d8e0bbb01de8d89b53481000bb8af20f5f19698f1d19351028cd7103b63d30de7d700000000000000";
        exSwapParams[1] = IApproveSwapAndPay.SwapParams({
            swapTarget: 0x8B741B0D79BE80E135C880F7583d427B4D41F015,
            maxGasForCall: 0,
            swapData: data
        });

        LiquidityManager.LoanInfo[] memory loanInfoArrayMemory = new LiquidityManager.LoanInfo[](1);
        loanInfoArrayMemory[0] = loanInfo;

        LiquidityBorrowingManager.BorrowParams
            memory AliceBorrowingParams = ILiquidityBorrowingManager.BorrowParams({
                internalSwapPoolfee: 3000,
                saleToken: address(USDT),
                holdToken: address(WAGMI),
                minHoldTokenOut: 0,
                maxMarginDeposit: type(uint256).max,
                maxDailyRate: type(uint256).max,
                externalSwap: exSwapParams,
                loans: loanInfoArrayMemory
            });

        borrowingManager.borrow(AliceBorrowingParams, block.timestamp + 60);
        bytes32[] memory AliceBorrowingKeys = borrowingManager.getBorrowingKeysForBorrower(
            address(alice)
        );
        vm.roll(block.number + 10);

        uint24 poolfeeTiers0 = 10000; //usdt-wmetis
        uint24 poolfeeTiers1 = 1500; //usdt-weth
        uint256 wagmi = 0;
        //uint256 kinetix = 1;
        uint256 dexIndx = wagmi;
        address secondToken0 = 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481; // wmetis  pool usdt-wmetis
        address secondToken1 = 0x420000000000000000000000000000000000000A; // weth   pool usdt-weth

        ILiquidityManager.FlashLoanParams[]
            memory flashLoanParams = new ILiquidityManager.FlashLoanParams[](2);
        flashLoanParams[0] = ILiquidityManager.FlashLoanParams({
            protocol: 1, //uniswap
            data: abi.encode(poolfeeTiers0, secondToken0, dexIndx)
        });
        flashLoanParams[1] = ILiquidityManager.FlashLoanParams({
            protocol: 1, //uniswap
            data: abi.encode(poolfeeTiers1, secondToken1, dexIndx)
        });

        ILiquidityManager.FlashLoanRoutes memory routes = ILiquidityManager.FlashLoanRoutes({
            strict: true,
            flashLoanParams: flashLoanParams
        });

        LiquidityBorrowingManager.RepayParams
            memory AliceRepayingParams = ILiquidityBorrowingManager.RepayParams({
                isEmergency: false,
                routes: routes,
                borrowingKey: AliceBorrowingKeys[0],
                minHoldTokenOut: 0,
                minSaleTokenOut: 0
            });
        // 1000 USDT from Vault
        deal(address(USDT), borrowingManager.VAULT_ADDRESS(), 1000e6);
        borrowingManager.repay(AliceRepayingParams, block.timestamp + 60);

        vm.stopPrank();
    }

    uint256 balanceBefore;

    function test_FlashLoanAggregator_UniV3_AAVE() public {
        deal(address(USDT), address(this), 1000e18);
        flashLoanAggregator.setWagmiLeverageAddress(address(this));

        bool zeroForSaleToken = address(USDT) < address(WAGMI);
        LiquidityManager.LoanInfo memory loan;
        uint24 poolfeeTiers = 10000; //usdt-wmetis
        address secondToken = 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481; // wmetis  pool usdt-wmetis
        uint256 wagmi = 0;
        // uint256 kinetix = 1;
        uint256 dexIndx = wagmi;

        ILiquidityManager.FlashLoanParams[]
            memory flashLoanParams = new ILiquidityManager.FlashLoanParams[](3);

        flashLoanParams[0] = ILiquidityManager.FlashLoanParams({
            protocol: 1, //uniswap
            data: abi.encode(poolfeeTiers, secondToken, dexIndx)
        });

        flashLoanParams[1] = ILiquidityManager.FlashLoanParams({
            protocol: 2, //aave
            data: "0x"
        });

        ILiquidityManager.FlashLoanRoutes memory routes = ILiquidityManager.FlashLoanRoutes({
            strict: true,
            flashLoanParams: flashLoanParams
        });
        ILiquidityManager.Amounts memory amounts;

        uint256 maxUsdtAmt = flashLoanAggregator.checkAaveFlashReserve(address(USDT));
        bytes memory data = abi.encode(
            ILiquidityManager.CallbackData({
                zeroForSaleToken: zeroForSaleToken,
                fee: 0,
                tickLower: 0,
                tickUpper: 0,
                saleToken: address(USDT),
                holdToken: 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481,
                holdTokenDebt: 0,
                vaultBodyDebt: 0,
                vaultFeeDebt: 0,
                amounts: amounts,
                loan: loan,
                routes: routes
            })
        );
        balanceBefore = address(USDT).getBalance();
        flashLoanAggregator.flashLoan(maxUsdtAmt, data);
    }

    function test_FlashLoanAggregator_AAVE_UniV3() public {
        deal(address(USDT), address(this), 1000e18);
        flashLoanAggregator.setWagmiLeverageAddress(address(this));

        bool zeroForSaleToken = address(USDT) < address(WAGMI);
        LiquidityManager.LoanInfo memory loan;
        uint24 poolfeeTiers = 10000; //usdt-wmetis
        address secondToken = 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481; // wmetis  pool usdt-wmetis
        uint256 wagmi = 0;
        // uint256 kinetix = 1;
        uint256 dexIndx = wagmi;

        ILiquidityManager.FlashLoanParams[]
            memory flashLoanParams = new ILiquidityManager.FlashLoanParams[](3);

        flashLoanParams[0] = ILiquidityManager.FlashLoanParams({
            protocol: 2, //aave
            data: "0x"
        });

        flashLoanParams[1] = ILiquidityManager.FlashLoanParams({
            protocol: 1, //uniswap
            data: abi.encode(poolfeeTiers, secondToken, dexIndx)
        });

        ILiquidityManager.FlashLoanRoutes memory routes = ILiquidityManager.FlashLoanRoutes({
            strict: true,
            flashLoanParams: flashLoanParams
        });
        ILiquidityManager.Amounts memory amounts;

        uint256 maxUsdtAmt = flashLoanAggregator.checkAaveFlashReserve(address(USDT));

        // console.log("maxUsdtAmt", maxUsdtAmt);
        bytes memory data = abi.encode(
            ILiquidityManager.CallbackData({
                zeroForSaleToken: zeroForSaleToken,
                fee: 0,
                tickLower: 0,
                tickUpper: 0,
                saleToken: address(USDT),
                holdToken: 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481,
                holdTokenDebt: 0,
                vaultBodyDebt: 0,
                vaultFeeDebt: 0,
                amounts: amounts,
                loan: loan,
                routes: routes
            })
        );
        balanceBefore = address(USDT).getBalance();
        //aave
        flashLoanAggregator.flashLoan(maxUsdtAmt, data);
        balanceBefore = address(USDT).getBalance();
        //aave+uniswap
        // 1000 USDT from Uniswap pool
        maxUsdtAmt = flashLoanAggregator.checkAaveFlashReserve(address(USDT)) + 1000 * 1e6;
        flashLoanAggregator.flashLoan(maxUsdtAmt, data);
    }

    function wagmiLeverageFlashCallback(
        uint256 bodyAmt,
        uint256 feeAmt,
        bytes calldata data
    ) external {
        ILiquidityManager.CallbackData memory decodedData = abi.decode(
            data,
            (ILiquidityManager.CallbackData)
        );
        uint256 balanceAfter = decodedData.saleToken.getBalance();
        assertEq(balanceAfter, balanceBefore + bodyAmt);
        decodedData.saleToken.safeTransfer(address(flashLoanAggregator), bodyAmt + feeAmt);
    }
}
