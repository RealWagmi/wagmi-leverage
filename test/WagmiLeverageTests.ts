import { ethers, network } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodePath } from "./testsHelpers/path";
import {
    hackDonor,
    maxApprove,
    zeroForOne,
    addLiquidity,
    PositionManagerPosInfo,
    PositionType,
    compareWithTolerance,
    getERC20Balance,
} from "./testsHelpers/helper";
import {
    time,
    mine,
    mineUpTo,
    takeSnapshot,
    SnapshotRestorer,
    impersonateAccount,
} from "@nomicfoundation/hardhat-network-helpers";

import {
    LiquidityBorrowingManager,
    IERC20,
    MockERC20FailApprove,
    IUniswapV3Pool,
    INonfungiblePositionManager,
    Vault,
    ISwapRouter,
    AggregatorMock,
} from "../typechain-types";

import {
    ApproveSwapAndPay,
    DailyRateAndCollateral,
    LiquidityManager,
} from "../typechain-types/contracts/LiquidityBorrowingManager";

import { BigNumber, parseFixed, formatFixed } from "@ethersproject/bignumber";
const { constants } = ethers;

describe("WagmiLeverageTests", () => {
    const DONOR_ADDRESS = "0xD51a44d3FaE010294C616388b506AcdA1bfAAE46";
    const WBTC_ADDRESS = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"; // 8 DECIMALS
    const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // DECIMALS 6
    const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // DECIMALS 18
    const WBTC_WETH_500_POOL_ADDRESS = "0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0";
    const WETH_USDT_500_POOL_ADDRESS = "0x11b815efB8f581194ae79006d24E0d814B7697F6";
    const WETH_USDT_3000_POOL_ADDRESS = "0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36";
    const WETH_USDT_10000_POOL_ADDRESS = "0xC5aF84701f98Fa483eCe78aF83F11b6C38ACA71D";
    const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const UNISWAP_V3_QUOTER_V2 = "0x61fFE014bA17989E743c5F6cB21bF9697530B21e";
    const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54"; /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const SWAP_ROUTER_ADDRESS = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const COLLATERAL_BALANCE_PRECISION = BigNumber.from("1000000000000000000");

    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let borrowingManager: LiquidityBorrowingManager;
    let pool500_WETH_USDT: IUniswapV3Pool;
    let pool500_WBTC_WETH: IUniswapV3Pool;
    let pool3000: IUniswapV3Pool;
    let pool10000: IUniswapV3Pool;
    let USDT: IERC20;
    let WETH: IERC20;
    let router: ISwapRouter;
    let aggregatorMock: AggregatorMock;
    let snapshot_global: SnapshotRestorer;
    let nonfungiblePositionManager: INonfungiblePositionManager;
    let vaultAddress: string;
    let vault: Vault;
    let nftpos: PositionManagerPosInfo[];
    let swapData: string;
    const swapIface = new ethers.utils.Interface(["function swap(bytes calldata wrappedCallData)"]);

    before(async () => {
        [owner, alice, bob] = await ethers.getSigners();

        USDT = await ethers.getContractAt("IERC20", USDT_ADDRESS);
        WETH = await ethers.getContractAt("IERC20", WETH_ADDRESS);
        pool500_WETH_USDT = await ethers.getContractAt("IUniswapV3Pool", WETH_USDT_500_POOL_ADDRESS);
        pool500_WBTC_WETH = await ethers.getContractAt("IUniswapV3Pool", WBTC_WETH_500_POOL_ADDRESS);
        nonfungiblePositionManager = await ethers.getContractAt(
            "INonfungiblePositionManager",
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS
        );
        router = await ethers.getContractAt("ISwapRouter", SWAP_ROUTER_ADDRESS);

        const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
        borrowingManager = await LiquidityBorrowingManager.deploy(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            UNISWAP_V3_QUOTER_V2,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
        await borrowingManager.deployed();
        const AggregatorMockFactory = await ethers.getContractFactory("AggregatorMock");
        aggregatorMock = await AggregatorMockFactory.deploy(UNISWAP_V3_QUOTER_V2);
        await aggregatorMock.deployed();
        vaultAddress = await borrowingManager.VAULT_ADDRESS();
        vault = await ethers.getContractAt("Vault", vaultAddress);
        const amountUSDT = ethers.utils.parseUnits("10000", 6);
        const amountWETH = ethers.utils.parseUnits("100", 18);
        const amountWBTC = ethers.utils.parseUnits("10", 8);
        await hackDonor(
            DONOR_ADDRESS,
            [owner.address, alice.address, bob.address, aggregatorMock.address],
            [
                { tokenAddress: USDT_ADDRESS, amount: amountUSDT },
                { tokenAddress: WETH_ADDRESS, amount: amountWETH },
                { tokenAddress: WBTC_ADDRESS, amount: amountWBTC },
            ]
        );
        await maxApprove(owner, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);
        await maxApprove(alice, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);
        await maxApprove(bob, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);
        await maxApprove(owner, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);
        await maxApprove(alice, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);
        await maxApprove(bob, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS, WBTC_ADDRESS]);

        nftpos = [];
        swapData = "0x";
    });

    it("should deploy LiquidityBorrowingManager correctly", async () => {
        expect(vaultAddress).not.to.be.undefined;
        expect(await borrowingManager.owner()).to.equal(owner.address);
        expect(await borrowingManager.dailyRateOperator()).to.equal(owner.address);
        expect(await borrowingManager.underlyingPositionManager()).to.equal(NONFUNGIBLE_POSITION_MANAGER_ADDRESS);
        expect(await borrowingManager.UNDERLYING_V3_FACTORY_ADDRESS()).to.equal(UNISWAP_V3_FACTORY);
        expect(await borrowingManager.UNDERLYING_V3_POOL_INIT_CODE_HASH()).to.equal(UNISWAP_V3_POOL_INIT_CODE_HASH);
        expect(await borrowingManager.computePoolAddress(USDT_ADDRESS, WETH_ADDRESS, 500)).to.equal(
            WETH_USDT_500_POOL_ADDRESS
        );

        expect(await borrowingManager.computePoolAddress(WBTC_ADDRESS, WETH_ADDRESS, 500)).to.equal(
            WBTC_WETH_500_POOL_ADDRESS
        );
    });

    it("should add swap target to whitelist will be successful", async () => {
        // onlyOwner
        await expect(borrowingManager.connect(alice).setSwapCallToWhitelist(aggregatorMock.address, "0x627dd56a", true))
            .to.be.reverted;
        await borrowingManager.connect(owner).setSwapCallToWhitelist(aggregatorMock.address, "0x627dd56a", true);
    });

    it("updating settings by the owner will be successful", async () => {
        let snapshot: SnapshotRestorer = await takeSnapshot();
        // PLATFORM_FEES_BP
        await expect(borrowingManager.connect(alice).updateSettings(0, [2000])).to.be.reverted;
        await expect(borrowingManager.connect(owner).updateSettings(0, [2001])).to.be.reverted;
        await expect(borrowingManager.connect(owner).updateSettings(0, [2000, 1])).to.be.reverted;
        await borrowingManager.connect(owner).updateSettings(0, [2000]);
        expect(await borrowingManager.platformFeesBP()).to.equal(2000);

        // DEFAULT_LIQUIDATION_BONUS
        await expect(borrowingManager.connect(owner).updateSettings(1, [101])).to.be.reverted; ////MAX_LIQUIDATION_BONUS = 100;
        await expect(borrowingManager.connect(owner).updateSettings(1, [101, 4])).to.be.reverted;
        await borrowingManager.connect(owner).updateSettings(1, [100]);
        expect(await borrowingManager.dafaultLiquidationBonusBP()).to.equal(100);

        // DAILY_RATE_OPERATOR
        await expect(borrowingManager.connect(owner).updateSettings(2, [bob.address, 20, 4])).to.be.reverted;
        await borrowingManager.connect(owner).updateSettings(2, [bob.address]);
        expect(await borrowingManager.dailyRateOperator()).to.equal(bob.address);

        // LIQUIDATION_BONUS_FOR_TOKEN
        await expect(borrowingManager.connect(owner).updateSettings(3, [USDT_ADDRESS, 101, 1000000])).to.be.reverted; ////MAX_LIQUIDATION_BONUS = 100;
        await expect(borrowingManager.connect(owner).updateSettings(3, [USDT_ADDRESS, 101, 1000000, 2])).to.be.reverted; ////MAX_LIQUIDATION_BONUS = 100;
        await borrowingManager.connect(owner).updateSettings(3, [USDT_ADDRESS, 99, 1000000]);
        expect((await borrowingManager.liquidationBonusForToken(USDT_ADDRESS)).bonusBP).to.equal(99);
        expect((await borrowingManager.liquidationBonusForToken(USDT_ADDRESS)).minBonusAmount).to.equal(1000000);
        await snapshot.restore();
    });

    it("approve positionManager NFT and check event", async () => {
        expect(
            await borrowingManager.getLiquidationBonus(WETH_ADDRESS, ethers.utils.parseUnits("100", 18), 1)
        ).to.be.equal(ethers.utils.parseUnits("0.69", 18));
        // UP LIQUIDATION_BONUS_FOR_TOKEN
        await borrowingManager.connect(owner).updateSettings(3, [WETH_ADDRESS, 69, 1000000]);
        await borrowingManager.connect(owner).updateSettings(3, [WBTC_ADDRESS, 69, 1000]);
        await borrowingManager.connect(owner).updateSettings(3, [USDT_ADDRESS, 69, 1000]);
        const amountWETH = ethers.utils.parseUnits("1", 18); //token0 token1
        const amountUSDT = ethers.utils.parseUnits("1800", 6); //token1
        const amountWBTC = ethers.utils.parseUnits("0.06", 8); //token0
        const amount0Desired = (await zeroForOne(USDT_ADDRESS, WETH_ADDRESS)) ? amountUSDT : amountWETH;
        const amount1Desired = (await zeroForOne(USDT_ADDRESS, WETH_ADDRESS)) ? amountWETH : amountUSDT;

        const amount0DesiredWBTC = (await zeroForOne(WBTC_ADDRESS, WETH_ADDRESS)) ? amountWBTC : amountWETH;
        const amount1DesiredWBTC = (await zeroForOne(WBTC_ADDRESS, WETH_ADDRESS)) ? amountWETH : amountWBTC;

        const range = 10;

        let pos: PositionManagerPosInfo = await addLiquidity(
            PositionType.LEFT_OUTRANGE_TOKEN_1,
            pool500_WETH_USDT,
            nonfungiblePositionManager,
            amount0Desired,
            amount1Desired,
            range,
            alice
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(
            nonfungiblePositionManager.connect(alice).approve(borrowingManager.address, pos.tokenId.toNumber())
        )
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(alice.address, borrowingManager.address, pos.tokenId);
        nftpos.push(pos);
        pos = await addLiquidity(
            PositionType.RIGHT_OUTRANGE_TOKEN_0,
            pool500_WETH_USDT,
            nonfungiblePositionManager,
            amount0Desired,
            amount1Desired,
            range,
            bob
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(nonfungiblePositionManager.connect(bob).approve(borrowingManager.address, pos.tokenId.toNumber()))
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(bob.address, borrowingManager.address, pos.tokenId);
        nftpos.push(pos);
        pos = await addLiquidity(
            PositionType.INRANGE_TOKEN_0_TOKEN_1,
            pool500_WETH_USDT,
            nonfungiblePositionManager,
            amount0Desired,
            amount1Desired,
            range,
            owner
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(
            nonfungiblePositionManager.connect(owner).approve(borrowingManager.address, pos.tokenId.toNumber())
        )
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(owner.address, borrowingManager.address, pos.tokenId);
        nftpos.push(pos);
        // WBTC_WETH_500_POOL_ADDRESS
        pos = await addLiquidity(
            PositionType.LEFT_OUTRANGE_TOKEN_1,
            pool500_WBTC_WETH,
            nonfungiblePositionManager,
            amount0DesiredWBTC,
            amount1DesiredWBTC,
            range,
            alice
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(
            nonfungiblePositionManager.connect(alice).approve(borrowingManager.address, pos.tokenId.toNumber())
        )
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(alice.address, borrowingManager.address, pos.tokenId);

        nftpos.push(pos);
        pos = await addLiquidity(
            PositionType.RIGHT_OUTRANGE_TOKEN_0,
            pool500_WBTC_WETH,
            nonfungiblePositionManager,
            amount0DesiredWBTC,
            amount1DesiredWBTC,
            range,
            bob
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(nonfungiblePositionManager.connect(bob).approve(borrowingManager.address, pos.tokenId.toNumber()))
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(bob.address, borrowingManager.address, pos.tokenId);
        nftpos.push(pos);
        pos = await addLiquidity(
            PositionType.INRANGE_TOKEN_0_TOKEN_1,
            pool500_WBTC_WETH,
            nonfungiblePositionManager,
            amount0DesiredWBTC,
            amount1DesiredWBTC,
            range,
            owner
        );
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        await expect(
            nonfungiblePositionManager.connect(owner).approve(borrowingManager.address, pos.tokenId.toNumber())
        )
            .to.emit(nonfungiblePositionManager, "Approval")
            .withArgs(owner.address, borrowingManager.address, pos.tokenId);
        nftpos.push(pos);

        snapshot_global = await takeSnapshot();
    });

    it("LEFT_OUTRANGE_TOKEN_1 borrowing liquidity (long position WBTC zeroForSaleToken = false)  will be successful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.05", 8); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[3].liquidity,
                tokenId: nftpos[3].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC.mul(2), //<=TooLittleReceivedError
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };

        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted;

        params = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("RIGHT_OUTRANGE_TOKEN_0 borrowing liquidity (long position WBTC zeroForSaleToken = false)  will be successful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.05", 8); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[4].liquidity,
                tokenId: nftpos[4].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };
        let snapshot: SnapshotRestorer = await takeSnapshot();
        await time.increase(86400);
        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted; //'Transaction too old'
        await snapshot.restore();
        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("INRANGE_TOKEN_0_TOKEN_1 borrowing liquidity (long position WBTC zeroForSaleToken = false)  will be successful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.05", 8); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[5].liquidity,
                tokenId: nftpos[5].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };

        let snapshot: SnapshotRestorer = await takeSnapshot();
        let debt: LiquidityBorrowingManager.BorrowingInfoExtStructOutput = (
            await borrowingManager.getBorrowerDebtsInfo(bob.address)
        )[0];
        //let collateralDebt = debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION);
        await time.increase(debt.estimatedLifeTime.toNumber() + 10);
        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.collateralBalance).to.be.lt(0);
        await borrowingManager.connect(bob).borrow(params, (await time.latest()) + 60);
        snapshot.restore();
        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("repay borrowing and restore liquidity (long position WBTC zeroForSaleToken = false) will be successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = (await time.latest()) + 60;
        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };
        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 1001, //<=slippage simulated
        };
        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted;
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await borrowingManager.connect(bob).repay(params, deadline);
        const rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(WETH_ADDRESS, WBTC_ADDRESS);
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);
        await time.increase(86400);
    });

    //================================================================================================
    it("LEFT_OUTRANGE_TOKEN_1 borrowing liquidity (long position WETH zeroForSaleToken = true)  will be successful", async () => {
        await snapshot_global.restore();
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[3].liquidity,
                tokenId: nftpos[3].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WBTC_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH.mul(2), //<=TooLittleReceivedError
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted;

        params = {
            internalSwapPoolfee: 500,
            saleToken: WBTC_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("RIGHT_OUTRANGE_TOKEN_0 borrowing liquidity (long position WETH zeroForSaleToken = true)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[4].liquidity,
                tokenId: nftpos[4].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WBTC_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };
        let snapshot: SnapshotRestorer = await takeSnapshot();
        await time.increase(86400);
        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted; //'Transaction too old'
        await snapshot.restore();
        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("INRANGE_TOKEN_0_TOKEN_1 borrowing liquidity (long position WETH zeroForSaleToken = true)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[5].liquidity,
                tokenId: nftpos[5].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WBTC_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        let snapshot: SnapshotRestorer = await takeSnapshot();
        let debt: LiquidityBorrowingManager.BorrowingInfoExtStructOutput = (
            await borrowingManager.getBorrowerDebtsInfo(bob.address)
        )[0];
        //let collateralDebt = debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION);
        await time.increase(debt.estimatedLifeTime.toNumber() + 10);
        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.collateralBalance).to.be.lt(0);
        await borrowingManager.connect(bob).borrow(params, (await time.latest()) + 60);
        snapshot.restore();
        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("repay borrowing and restore liquidity (long position WETH zeroForSaleToken = true) will be successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = (await time.latest()) + 60;
        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };
        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 1001, //<=slippage simulated
        };
        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted;
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await borrowingManager.connect(bob).repay(params, deadline);
        const rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(WBTC_ADDRESS, WETH_ADDRESS);
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);
        await time.increase(86400);
    });
    //===========================================================================================

    it("LEFT_OUTRANGE_TOKEN_1 borrowing liquidity (long position WETH)  will be successful", async () => {
        await snapshot_global.restore();
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[0].liquidity,
                tokenId: nftpos[0].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH.mul(2), //<=TooLittleReceivedError
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted;

        params = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("RIGHT_OUTRANGE_TOKEN_0 borrowing liquidity (long position WETH)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[1].liquidity,
                tokenId: nftpos[1].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("INRANGE_TOKEN_0_TOKEN_1 borrowing liquidity (long position WETH)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.88", 18);
        let deadline = (await time.latest()) + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [
            {
                liquidity: nftpos[2].liquidity,
                tokenId: nftpos[2].tokenId,
            },
        ];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        let snapshot: SnapshotRestorer = await takeSnapshot();
        let debt: LiquidityBorrowingManager.BorrowingInfoExtStructOutput = (
            await borrowingManager.getBorrowerDebtsInfo(bob.address)
        )[0];
        //let collateralDebt = debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION);
        await time.increase(debt.estimatedLifeTime.toNumber() + 10);
        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.collateralBalance).to.be.lt(0);
        await borrowingManager.connect(bob).borrow(params, (await time.latest()) + 60);
        snapshot.restore();
        await borrowingManager.connect(bob).borrow(params, deadline);
        await time.increase(10000);
    });

    it("repay borrowing and restore liquidity will be successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = (await time.latest()) + 60;
        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };
        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 1001, //<=slippage simulated
        };
        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted; //SwapSlippageCheckError(1810779133, 1808970163)
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await borrowingManager.connect(bob).repay(params, deadline);
        const rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(USDT_ADDRESS, WETH_ADDRESS);
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);
        await time.increase(86400);
    });

    it("borrowing too little liquidity will be unsuccessful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.2", 8); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 80;
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, WBTC_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let loans = [
            {
                liquidity: BigNumber.from(100000), ////TooLittleBorrowedLiquidity(100000)
                tokenId: nftpos[3].tokenId,
            },
            {
                liquidity: nftpos[4].liquidity,
                tokenId: nftpos[4].tokenId,
            },
            {
                liquidity: nftpos[5].liquidity, //correct
                tokenId: nftpos[5].tokenId,
            },
        ];

        let params = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: BigNumber.from(1), //amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };

        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted;
    });

    it("borrowing liquidity from different pools will be unsuccessful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.2", 8); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 80;
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, WBTC_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let loans = [
            {
                liquidity: nftpos[3].liquidity,
                tokenId: nftpos[3].tokenId,
            },
            {
                liquidity: nftpos[4].liquidity,
                tokenId: nftpos[4].tokenId,
            },
            {
                liquidity: nftpos[1].liquidity, //fail
                tokenId: nftpos[1].tokenId, ////fail
            },
        ];

        let params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };

        await expect(borrowingManager.connect(bob).borrow(params, deadline)).to.be.reverted;
    });

    it("borrowing all liquidity in one transaction (long position WBTC & WETH) using an external swap will be successful", async () => {
        const amountWBTC = ethers.utils.parseUnits("0.2", 8); //token0
        const amountWETH = ethers.utils.parseUnits("2.90", 18); //token0
        const deadline = (await time.latest()) + 60;
        const minLeverageDesired = 80;
        const maxCollateral = amountWETH.div(minLeverageDesired);
        const maxCollateralWBTC = amountWBTC.div(minLeverageDesired);

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, WBTC_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let loans = [
            {
                liquidity: nftpos[3].liquidity, //correct
                tokenId: nftpos[3].tokenId,
            },
            {
                liquidity: nftpos[4].liquidity,
                tokenId: nftpos[4].tokenId,
            },
            {
                liquidity: nftpos[5].liquidity, //correct
                tokenId: nftpos[5].tokenId,
            },
        ];

        let params = {
            internalSwapPoolfee: 500,
            saleToken: WETH_ADDRESS,
            holdToken: WBTC_ADDRESS,
            minHoldTokenOut: amountWBTC,
            maxCollateral: maxCollateralWBTC,
            externalSwap: swapParams,
            loans: loans,
        };
        await borrowingManager.connect(bob).borrow(params, deadline);
        let debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.estimatedLifeTime).to.be.gte(86400); // >= 1 day for tokens with a small decemals
        let roundUpvalue = debt.info.borrowedAmount.mul(10).mod(10000).gt(0) ? 1 : 0;
        let collateralBalance = debt.collateralBalance;
        expect(collateralBalance).to.be.equal(
            ethers.utils.parseUnits(debt.info.borrowedAmount.mul(10).div(10000).add(roundUpvalue).toString(), 18)
        ); // 0.1% borrowedAmount

        swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [USDT_ADDRESS, WETH_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        swapParams = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        loans = [
            {
                liquidity: nftpos[0].liquidity,
                tokenId: nftpos[0].tokenId,
            },
            {
                liquidity: nftpos[1].liquidity,
                tokenId: nftpos[1].tokenId,
            },
            {
                liquidity: nftpos[2].liquidity, //correct
                tokenId: nftpos[2].tokenId,
            },
        ];

        params = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,
            externalSwap: swapParams,
            loans: loans,
        };

        await borrowingManager.connect(bob).borrow(params, deadline);

        //console.log(await borrowingManager.getBorrowerDebtsInfo(bob.address));
    });

    it("updating the daily rate should be correct", async () => {
        expect((await borrowingManager.getHoldTokenDailyRateInfo(USDT_ADDRESS, WETH_ADDRESS))[0]).to.be.equal(10); // 0.1% default rate
        let latest = await time.latest();
        let debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[1];
        expect(debt.estimatedLifeTime).to.be.equal(86400); // 1 day
        let roundUpvalue = debt.info.borrowedAmount.mul(10).mod(10000).gt(0) ? 1 : 0;
        let collateralBalance = debt.collateralBalance;

        expect(collateralBalance).to.be.equal(
            ethers.utils.parseUnits(debt.info.borrowedAmount.mul(10).div(10000).add(roundUpvalue).toString(), 18)
        ); // 0.1% borrowedAmount
        await time.increaseTo(latest + 43200); //12 hours

        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[1];
        expect(debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION)).to.be.equal(
            collateralBalance.div(2).div(COLLATERAL_BALANCE_PRECISION)
        );
        expect(debt.estimatedLifeTime).to.be.equal(43200); //24-12=12 Hours
        await borrowingManager.connect(owner).updateHoldTokenDailyRate(USDT_ADDRESS, WETH_ADDRESS, 20); //0.2% MULTIPLE x2
        await time.increaseTo(latest + 43200 + 21600 + 1);

        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[1];
        expect(debt.estimatedLifeTime).to.be.equal(0);
        expect(debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION)).to.be.lte(0);

        await expect(borrowingManager.connect(owner).updateHoldTokenDailyRate(USDT_ADDRESS, WETH_ADDRESS, 200)).to.be
            .reverted;
        await expect(borrowingManager.connect(owner).updateHoldTokenDailyRate(USDT_ADDRESS, WETH_ADDRESS, 1)).to.be
            .reverted;
        snapshot_global = await takeSnapshot();
    });

    it("emergency repay will be successful for PosManNFT owner if the collateral is depleted", async () => {
        let debt: LiquidityBorrowingManager.BorrowingInfoExtStructOutput[] =
            await borrowingManager.getBorrowerDebtsInfo(bob.address);
        await time.increase(debt[1].estimatedLifeTime.toNumber() + 1);

        let borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 1);
        let deadline = (await time.latest()) + 60;

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [constants.AddressZero, constants.AddressZero, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: true, //emergency
            internalSwapPoolfee: 0,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 0,
        };

        //console.log(debt);
        let loans: LiquidityManager.LoanInfoStructOutput[] = await borrowingManager.getLoansInfo(borrowingKey);
        expect(loans.length).to.equal(3);
        //console.log(loans);
        await expect(borrowingManager.connect(alice).repay(params, deadline))
            .to.emit(borrowingManager, "EmergencyLoanClosure")
            .withArgs(bob.address, alice.address, borrowingKey);

        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[1].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[2].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[3].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[4].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[5].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(2);

        debt = await borrowingManager.getBorrowerDebtsInfo(bob.address);
        //console.log(debt);
        loans = await borrowingManager.getLoansInfo(borrowingKey);
        expect(loans.length).to.equal(2);

        await time.increase(100);
        deadline = (await time.latest()) + 60;
        await expect(borrowingManager.connect(bob).repay(params, deadline))
            .to.emit(borrowingManager, "EmergencyLoanClosure")
            .withArgs(bob.address, bob.address, borrowingKey);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[1].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[2].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[3].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[4].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[5].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(2);
        debt = await borrowingManager.getBorrowerDebtsInfo(bob.address);
        //console.log(debt);
        loans = await borrowingManager.getLoansInfo(borrowingKey);
        expect(loans.length).to.equal(1);

        await time.increase(100);
        deadline = (await time.latest()) + 60;
        await expect(borrowingManager.connect(owner).repay(params, deadline))
            .to.emit(borrowingManager, "EmergencyLoanClosure")
            .withArgs(bob.address, owner.address, borrowingKey);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[1].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[2].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[3].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[4].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[5].tokenId)).to.be.gt(0);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(1);
    });

    it("Loan liquidation will be successful for anyone if the collateral is depleted", async () => {
        snapshot_global.restore();
        let borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 1);
        let deadline = (await time.latest()) + 60;

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, USDT_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };

        await borrowingManager.connect(alice).repay(params, deadline);

        let debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        await time.increase(debt.estimatedLifeTime.toNumber() + 1);

        // WBTC_WETH
        borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        // internal swap
        swapParams = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: "0x",
        };
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await expect(borrowingManager.connect(alice).repay(params, deadline)).to.be.reverted; // too old
        deadline = (await time.latest()) + 60;
        await borrowingManager.connect(alice).repay(params, deadline);

        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[1].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[2].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[3].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[4].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[5].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(0);
    });

    it("takeOverDebt should be correct if the collateral is depleted", async () => {
        snapshot_global.restore();
        const aliceBorrowingsCount = await borrowingManager.getBorrowerDebtsCount(alice.address);
        const bobBorrowingsCount = await borrowingManager.getBorrowerDebtsCount(bob.address);
        let debt: LiquidityBorrowingManager.BorrowingInfoExtStructOutput = (
            await borrowingManager.getBorrowerDebtsInfo(bob.address)
        )[0];
        expect(debt.collateralBalance).to.be.gte(0);
        let collateralDebt = debt.collateralBalance.div(COLLATERAL_BALANCE_PRECISION);
        await expect(borrowingManager.connect(alice).takeOverDebt(debt.key, collateralDebt)).to.be.reverted; // forbidden
        await time.increase(debt.estimatedLifeTime.toNumber() + 10);
        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.collateralBalance).to.be.lt(0);
        collateralDebt = debt.collateralBalance.abs().div(COLLATERAL_BALANCE_PRECISION).add(1);
        await expect(borrowingManager.connect(alice).takeOverDebt(debt.key, collateralDebt)).to.be.reverted; //collateralAmt is not enough
        await borrowingManager.connect(alice).takeOverDebt(debt.key, collateralDebt.add(5));
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(bobBorrowingsCount.sub(1));
        expect(await borrowingManager.getBorrowerDebtsCount(alice.address)).to.be.equal(aliceBorrowingsCount.add(1));
        const borrowingsInfo = await borrowingManager.borrowingsInfo(debt.key);
        expect(borrowingsInfo.borrower).to.be.equal(constants.AddressZero);
    });

    it("increase the collateral balance should be correct", async () => {
        snapshot_global.restore();
        const key = await borrowingManager.userBorrowingKeys(bob.address, 1);
        const ocKey = ethers.utils
            .solidityKeccak256(["address", "address", "address"], [bob.address, USDT_ADDRESS, WETH_ADDRESS])
            .toString();
        expect(key).to.be.equal(ocKey);
        let collateralAmt = await borrowingManager.calculateCollateralAmtForLifetime(key, 86400);

        let debtBefore = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[1];
        let debtOncollateral = debtBefore.collateralBalance.div(COLLATERAL_BALANCE_PRECISION);
        if (debtOncollateral.lt(0)) {
            debtOncollateral = debtOncollateral.abs();
        } else {
            debtOncollateral = BigNumber.from(0);
        }

        await borrowingManager.connect(bob).increaseCollateralBalance(key, collateralAmt.add(debtOncollateral)); // +1 seconds
        let debtAfter = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[1];

        expect(debtAfter.estimatedLifeTime).to.be.within(
            debtBefore.estimatedLifeTime.add(86398),
            debtBefore.estimatedLifeTime.add(86399)
        );
    });

    it("get-functions should be call successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 1);
        const { balance, estimatedLifeTime } = await borrowingManager.checkDailyRateCollateral(borrowingKey);
        expect(balance).to.be.gt(0);
        expect(estimatedLifeTime).to.be.gt(86000);
        let extinfo: LiquidityBorrowingManager.BorrowingInfoExtStructOutput[] =
            await borrowingManager.getLenderCreditsInfo(nftpos[0].tokenId);
        expect(extinfo[0].key).to.be.equal(borrowingKey);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(1);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(2);

        let rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(WETH_ADDRESS, USDT_ADDRESS);
        expect(rateInfo[0]).to.be.equal(10); // default
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);
        rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(USDT_ADDRESS, WETH_ADDRESS);
        expect(rateInfo[0]).to.be.equal(20);
        expect(rateInfo[1].totalBorrowed).to.be.gt(0);
        extinfo = await borrowingManager.getBorrowerDebtsInfo(bob.address);
        expect(extinfo[1].key).to.be.equal(borrowingKey);

        const loansInfo: LiquidityManager.LoanInfoStructOutput[] = await borrowingManager.getLoansInfo(borrowingKey);
        expect(loansInfo.length).to.be.equal(3);
        expect(loansInfo[0].tokenId).to.be.equal(nftpos[0].tokenId);
    });

    it("using external swap with non-whitelisted parameters will fail", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 1);
        const deadline = (await time.latest()) + 60;

        const swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, USDT_ADDRESS, 0, 0]
        );
        const nonWhitelistedSwapIface = new ethers.utils.Interface([
            "function nonWhitelistedSwap(bytes calldata wrappedCallData)",
        ]);
        swapData = nonWhitelistedSwapIface.encodeFunctionData("nonWhitelistedSwap", [swap_params]);

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        const params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted;
    });

    it("repay borrowing and restore liquidity using an external swap will be successful", async () => {
        let borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 1);
        const deadline = (await time.latest()) + 60;

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, USDT_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        let params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        // borrower only
        await expect(borrowingManager.connect(alice).repay(params, deadline)).to.be.reverted;
        await borrowingManager.connect(bob).repay(params, deadline);
        let rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(USDT_ADDRESS, WETH_ADDRESS);
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);

        // WBTC_WETH
        borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        // external swap
        swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WBTC_ADDRESS, WETH_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        swapParams = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 1001, //<=slippage simulated
        };

        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted; //SwapSlippageCheckError(1006138392650352999, 1005133259390962037)
        params = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990, //1%
        };
        await expect(borrowingManager.connect(alice).repay(params, deadline)).to.be.reverted;
        await borrowingManager.connect(bob).repay(params, deadline);

        rateInfo = await borrowingManager.getHoldTokenDailyRateInfo(WETH_ADDRESS, WBTC_ADDRESS);
        expect(rateInfo[1].totalBorrowed).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[0].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[1].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[2].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[3].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[4].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getLenderCreditsCount(nftpos[5].tokenId)).to.be.equal(0);
        expect(await borrowingManager.getBorrowerDebtsCount(bob.address)).to.be.equal(0);
    });

    it("Vault test should be successful", async () => {
        const balances = await vault.getBalances([USDT_ADDRESS, WETH_ADDRESS]);
        expect(balances[0]).to.be.equal(0);
        expect(balances[1]).to.be.gt(0);
        await expect(vault.connect(owner).transferToken(WETH_ADDRESS, owner.address, BigNumber.from(1))).to.be.reverted;
    });

    it("collect protocol fees should be successful", async () => {
        const aliceBalanceBefore = await getERC20Balance(WETH_ADDRESS, alice.address);
        let fees = await borrowingManager.getPlatformsFeesInfo([USDT_ADDRESS, WETH_ADDRESS]);
        expect(fees[0]).to.be.equal(0);
        expect(fees[1]).to.be.gt(0);
        await expect(borrowingManager.connect(alice).collectProtocol(alice.address, [USDT_ADDRESS, WETH_ADDRESS])).to.be
            .reverted;
        await borrowingManager.connect(owner).collectProtocol(alice.address, [USDT_ADDRESS, WETH_ADDRESS]);
        const aliceBalanceAfter = await getERC20Balance(WETH_ADDRESS, alice.address);
        expect(aliceBalanceAfter).to.be.equal(aliceBalanceBefore.add(fees[1]));
        fees = await borrowingManager.getPlatformsFeesInfo([USDT_ADDRESS, WETH_ADDRESS]);
        expect(fees[1]).to.be.equal(0);
    });

    it("testing some internal functions", async () => {
        const amountUSDT = ethers.utils.parseUnits("100", 6);
        const $ApproveSwapAndPay = await ethers.getContractFactory("$ApproveSwapAndPay");
        const $approveSwapAndPay = await $ApproveSwapAndPay.deploy(UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH);
        await maxApprove(owner, $approveSwapAndPay.address, [USDT_ADDRESS]);
        await $approveSwapAndPay.$_pay(USDT_ADDRESS, owner.address, $approveSwapAndPay.address, amountUSDT);
        const usdtBalance = await $approveSwapAndPay.$_getBalance(USDT_ADDRESS);
        expect(usdtBalance).to.be.equal(amountUSDT);
        const v3SwapExactInputParams = {
            fee: 500,
            tokenIn: USDT_ADDRESS,
            tokenOut: WETH_ADDRESS,
            amountIn: amountUSDT,
            amountOutMinimum: 0,
        };
        await $approveSwapAndPay.$_v3SwapExactInput(v3SwapExactInputParams);

        await $approveSwapAndPay.$_pay(USDT_ADDRESS, owner.address, $approveSwapAndPay.address, amountUSDT);

        let swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [USDT_ADDRESS, WETH_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        let swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData,
        };

        await expect(
            $approveSwapAndPay.$_patchAmountsAndCallSwap(USDT_ADDRESS, WETH_ADDRESS, swapParams, amountUSDT, 0)
        ).to.be.reverted; //swap is not white-listed
        await $approveSwapAndPay.$setSwapCallToWhitelist(aggregatorMock.address, "0x627dd56a", true);
        await $approveSwapAndPay.$_patchAmountsAndCallSwap(USDT_ADDRESS, WETH_ADDRESS, swapParams, amountUSDT, 0);

        await $approveSwapAndPay.$_pay(USDT_ADDRESS, owner.address, $approveSwapAndPay.address, amountUSDT);
        // without patching
        swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [USDT_ADDRESS, WETH_ADDRESS, amountUSDT, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        swapParams = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 1000000,
            swapData: swapData,
        };
        await $approveSwapAndPay.$_patchAmountsAndCallSwap(USDT_ADDRESS, WETH_ADDRESS, swapParams, 0, 0);
        await $approveSwapAndPay.$_maxApproveIfNecessary(USDT_ADDRESS, aggregatorMock.address, constants.MaxUint256);

        let factoryMockERC20FailApprove = await ethers.getContractFactory("MockERC20FailApprove");
        let failApproveToken = await factoryMockERC20FailApprove.deploy("fail", "fail");
        await failApproveToken.deployed();
        await $approveSwapAndPay.$_maxApproveIfNecessary(
            failApproveToken.address,
            "0x0000000000000000000000000000000000000002",
            constants.MaxUint256
        );
        await $approveSwapAndPay.$_maxApproveIfNecessary(
            failApproveToken.address,
            "0x0000000000000000000000000000000000000001",
            constants.MaxUint256
        );
        await expect(
            $approveSwapAndPay.$_maxApproveIfNecessary(
                failApproveToken.address,
                "0x0000000000000000000000000000000000000003",
                constants.MaxUint256
            )
        ).to.be.reverted; //require(_tryApprove(token, spender, 0));
        await expect(
            $approveSwapAndPay.$_maxApproveIfNecessary(
                failApproveToken.address,
                "0x0000000000000000000000000000000000000004",
                constants.MaxUint256
            )
        ).to.be.reverted; //failed to approve

        let key0 = $approveSwapAndPay.$_computePairKey(USDT_ADDRESS, WETH_ADDRESS);
        await $approveSwapAndPay.$_addKeyIfNotExists(key0);
        expect(await $approveSwapAndPay.$_addKeyIfNotExists(key0)).to.be.ok;
        let key1 = $approveSwapAndPay.$_computePairKey(WETH_ADDRESS, USDT_ADDRESS);
        await $approveSwapAndPay.$_addKeyIfNotExists(key1);
        let self: any[] = await $approveSwapAndPay.$getSelf();
        expect(self.length).to.be.equal(2);
        await $approveSwapAndPay.$_removeKey(key1);
        expect(await $approveSwapAndPay.$_removeKey(key1)).to.be.ok;
        self = await $approveSwapAndPay.$getSelf();
        expect(self.length).to.be.equal(1);
        await $approveSwapAndPay.$_removeKey(key0);
        self = await $approveSwapAndPay.$getSelf();
        expect(self.length).to.be.equal(0);
        expect(await $approveSwapAndPay.$_removeKey(key0)).to.be.ok;
    });
});
