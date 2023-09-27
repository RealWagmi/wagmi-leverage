import { ethers, network } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodePath } from "./testsHelpers/path";
import { hackDonor, maxApprove, zeroForOne, addLiquidity, PositionManagerPosInfo, PositionType, compareWithTolerance } from "./testsHelpers/helper";
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
    IUniswapV3Pool,
    INonfungiblePositionManager,
    Vault,
    ISwapRouter,
    LiquidityManager,
    AggregatorMock,
} from "../typechain-types";

import { ApproveSwapAndPay } from "../typechain-types/contracts/LiquidityBorrowingManager";
import { BigNumber, parseFixed, formatFixed } from "@ethersproject/bignumber";
const { constants } = ethers;

describe("WagmiLeverageTests", () => {
    const DONOR_ADDRESS = "0xD51a44d3FaE010294C616388b506AcdA1bfAAE46";
    const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // DECIMALS 6
    const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // DECIMALS 18
    const WETH_USDT_500_POOL_ADDRESS = "0x11b815efB8f581194ae79006d24E0d814B7697F6";
    const WETH_USDT_3000_POOL_ADDRESS = "0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36";
    const WETH_USDT_10000_POOL_ADDRESS = "0xC5aF84701f98Fa483eCe78aF83F11b6C38ACA71D";
    const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";/// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";/// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const UNISWAP_V3_QUOTER_V2 = "0x61fFE014bA17989E743c5F6cB21bF9697530B21e";
    const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";/// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const SWAP_ROUTER_ADDRESS = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let borrowingManager: LiquidityBorrowingManager;
    let pool500: IUniswapV3Pool;
    let pool3000: IUniswapV3Pool;
    let pool10000: IUniswapV3Pool;
    let USDT: IERC20;
    let WETH: IERC20;
    let router: ISwapRouter;
    let aggregatorMock: AggregatorMock;
    let snapshot_global: SnapshotRestorer;
    let nonfungiblePositionManager: INonfungiblePositionManager;
    let vaultAddress: string;
    let nftpos: PositionManagerPosInfo[];
    let swapData: string;
    const swapIface = new ethers.utils.Interface(["function swap(bytes calldata wrappedCallData)"]);



    before(async () => {

        [owner, alice, bob] = await ethers.getSigners();
        USDT = await ethers.getContractAt("IERC20", USDT_ADDRESS);
        WETH = await ethers.getContractAt("IERC20", WETH_ADDRESS);
        pool500 = await ethers.getContractAt("IUniswapV3Pool", WETH_USDT_500_POOL_ADDRESS);
        pool3000 = await ethers.getContractAt("IUniswapV3Pool", WETH_USDT_3000_POOL_ADDRESS);
        pool10000 = await ethers.getContractAt("IUniswapV3Pool", WETH_USDT_10000_POOL_ADDRESS);
        nonfungiblePositionManager = await ethers.getContractAt("INonfungiblePositionManager", NONFUNGIBLE_POSITION_MANAGER_ADDRESS);
        router = await ethers.getContractAt("ISwapRouter", SWAP_ROUTER_ADDRESS);

        const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
        borrowingManager = await LiquidityBorrowingManager.deploy(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, UNISWAP_V3_QUOTER_V2, UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH);
        await borrowingManager.deployed();
        const AggregatorMockFactory = await ethers.getContractFactory("AggregatorMock");
        aggregatorMock = await AggregatorMockFactory.deploy(UNISWAP_V3_QUOTER_V2);
        await aggregatorMock.deployed();
        vaultAddress = await borrowingManager.VAULT_ADDRESS();
        const amountUSDT = ethers.utils.parseUnits("10000", 6);
        const amountWETH = ethers.utils.parseUnits("100", 18);
        await hackDonor(
            DONOR_ADDRESS,
            [owner.address, alice.address, bob.address, aggregatorMock.address],
            [
                { tokenAddress: USDT_ADDRESS, amount: amountUSDT },
                { tokenAddress: WETH_ADDRESS, amount: amountWETH },
            ]
        );
        await maxApprove(owner, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS]);
        await maxApprove(alice, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS]);
        await maxApprove(bob, nonfungiblePositionManager.address, [USDT_ADDRESS, WETH_ADDRESS]);
        await maxApprove(owner, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS]);
        await maxApprove(alice, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS]);
        await maxApprove(bob, borrowingManager.address, [USDT_ADDRESS, WETH_ADDRESS]);

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
        expect(await borrowingManager.computePoolAddress(USDT_ADDRESS, WETH_ADDRESS, 500)).to.equal(WETH_USDT_500_POOL_ADDRESS);
    });

    it("should add swap target to whitelist will be successful", async () => {
        // onlyOwner
        await expect(borrowingManager.connect(alice).setSwapCallToWhitelist(aggregatorMock.address, "0x627dd56a", true)).to.be.reverted;
        await borrowingManager.connect(owner).setSwapCallToWhitelist(aggregatorMock.address, "0x627dd56a", true);
    });

    it("updating settings by the owner will be successful", async () => {
        let snapshot: SnapshotRestorer = await takeSnapshot();
        // PLATFORM_FEES_BP
        await expect(borrowingManager.connect(alice).updateSettings(0, [2000])).to.be.reverted;
        await borrowingManager.connect(owner).updateSettings(0, [2000]);
        expect(await borrowingManager.platformFeesBP()).to.equal(2000);

        // LIQUIDATION_BONUS_BP
        await borrowingManager.connect(owner).updateSettings(1, [100]);
        expect(await borrowingManager.dafaultLiquidationBonusBP()).to.equal(100);

        // DAILY_RATE_OPERATOR
        await borrowingManager.connect(owner).updateSettings(2, [bob.address]);
        expect(await borrowingManager.dailyRateOperator()).to.equal(bob.address);

        // SPECIFIC_TOKEN_LIQUIDATION_BONUS_BP
        await expect(borrowingManager.connect(owner).updateSettings(3, [200, USDT_ADDRESS])).to.be.reverted;////MAX_LIQUIDATION_BONUS = 100;
        await borrowingManager.connect(owner).updateSettings(3, [99, USDT_ADDRESS]);
        expect(await borrowingManager.specificTokenLiquidationBonus(USDT_ADDRESS)).to.equal(99);
        await snapshot.restore();
    });

    it("approve positionManager NFT and check event", async () => {
        const amountWETH = ethers.utils.parseUnits("1", 18);//token0
        const amountUSDT = ethers.utils.parseUnits("1800", 6);//token1
        const amount0Desired = await zeroForOne(USDT_ADDRESS, WETH_ADDRESS) ? amountUSDT : amountWETH;
        const amount1Desired = await zeroForOne(USDT_ADDRESS, WETH_ADDRESS) ? amountWETH : amountUSDT;
        const range = 10;


        let pos: PositionManagerPosInfo = await addLiquidity(PositionType.LEFT_OUTRANGE_TOKEN_1, pool500, nonfungiblePositionManager, amount0Desired, amount1Desired, range, alice);
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        nftpos.push(pos);
        pos = await addLiquidity(PositionType.RIGHT_OUTRANGE_TOKEN_0, pool500, nonfungiblePositionManager, amount0Desired, amount1Desired, range, alice);
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        nftpos.push(pos);
        pos = await addLiquidity(PositionType.INRANGE_TOKEN_0_TOKEN_1, pool500, nonfungiblePositionManager, amount0Desired, amount1Desired, range, alice);
        expect(pos.liquidity).to.be.above(BigNumber.from(0));
        nftpos.push(pos);
        // approve NFT position to LiquidityBorrowingManager
        for (pos of nftpos) {
            // console.log(pos.tokenId.toNumber());
            expect(await nonfungiblePositionManager.ownerOf(pos.tokenId)).to.equal(alice.address);
            await expect(
                nonfungiblePositionManager.connect(alice).approve(borrowingManager.address, pos.tokenId.toNumber())
            )
                .to.emit(nonfungiblePositionManager, "Approval")
                .withArgs(alice.address, borrowingManager.address, pos.tokenId);
        }

    });

    it("LEFT_OUTRANGE_TOKEN_1 borrowing liquidity (long position WETH)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.98", 18);//token0
        const deadline = await time.latest() + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [{
            liquidity: nftpos[0].liquidity,
            tokenId: nftpos[0].tokenId
        }];


        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,//there will be no token sale, there will be no swap
            externalSwap: swapParams,
            loans: loans
        }

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("RIGHT_OUTRANGE_TOKEN_0 borrowing liquidity (long position WETH)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.98", 18);//token0
        const deadline = await time.latest() + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [{
            liquidity: nftpos[1].liquidity,
            tokenId: nftpos[1].tokenId
        }];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,//there will be no token sale, there will be no swap
            externalSwap: swapParams,
            loans: loans
        }

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("INRANGE_TOKEN_0_TOKEN_1 borrowing liquidity (long position WETH)  will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("0.98", 18);//token0
        const deadline = await time.latest() + 60;
        const minLeverageDesired = 50;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [{
            liquidity: nftpos[2].liquidity,
            tokenId: nftpos[2].tokenId
        }];

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,//there will be no token sale, there will be no swap
            externalSwap: swapParams,
            loans: loans
        }

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

    it("repay borrowing and restore liquidity will be successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = await time.latest() + 60;
        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountInDataIndex: 0,
            maxGasForCall: 0,
            swapData: swapData
        }
        const params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990 //1%

        }
        await borrowingManager.connect(bob).repay(params, deadline);
    });

    it("borrowing all liquidity in one transaction (long position WETH) using an external swap will be successful", async () => {
        const amountWETH = ethers.utils.parseUnits("2.90", 18);//token0
        const deadline = await time.latest() + 60;
        const minLeverageDesired = 80;
        const maxCollateral = amountWETH.div(minLeverageDesired);

        const loans = [{
            liquidity: nftpos[0].liquidity,
            tokenId: nftpos[0].tokenId
        }, {
            liquidity: nftpos[1].liquidity,
            tokenId: nftpos[1].tokenId
        }, {
            liquidity: nftpos[2].liquidity,
            tokenId: nftpos[2].tokenId
        }];

        const swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [USDT_ADDRESS, WETH_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            internalSwapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,//there will be no token sale, there will be no swap
            externalSwap: swapParams,
            loans: loans
        }

        await borrowingManager.connect(bob).borrow(params, deadline);
        snapshot_global = await takeSnapshot();
        //console.log(await borrowingManager.getBorrowerDebtsInfo(bob.address));
    });

    it("updating the daily rate should be correct", async () => {
        expect(await borrowingManager.getHoldTokenDailyRate(USDT_ADDRESS, WETH_ADDRESS)).to.be.equal(10);// 0.1% default rate
        let latest = await time.latest();
        let debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.estimatedLifeTime).to.be.equal(86400);// 1 day
        let roundUpvalue = debt.info.borrowedAmount.mul(10).mod(10000).gt(0) ? 1 : 0;
        let collateralBalance = debt.collateralBalance;

        expect(collateralBalance).to.be.equal(ethers.utils.parseUnits((debt.info.borrowedAmount.mul(10).div(10000).add(roundUpvalue)).toString(), 18));// 0.1% borrowedAmount
        await time.increaseTo(latest + 43200);//12 hours

        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.collateralBalance.div("1000000000000000000")).to.be.equal(collateralBalance.div(2).div("1000000000000000000"));
        expect(debt.estimatedLifeTime).to.be.equal(43200);//24-12=12 Hours
        await borrowingManager.connect(owner).updateHoldTokenDailyRate(USDT_ADDRESS, WETH_ADDRESS, 20);//0.2% MULTIPLE x2
        await time.increaseTo(latest + 43200 + 21600 + 1);

        debt = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        expect(debt.estimatedLifeTime).to.be.equal(0);
        expect(debt.collateralBalance.div("1000000000000000000")).to.be.lte(0);

    });

    it("increase the collateral balance should be correct", async () => {

        const key = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const ocKey = ethers.utils.solidityKeccak256(["address", "address", "address"], [bob.address, USDT_ADDRESS, WETH_ADDRESS]).toString();
        expect(key).to.be.equal(ocKey);
        let collateralAmt = await borrowingManager.calculateCollateralAmtForLifetime(key, 86400);

        let debtBefore = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];
        let debtOncollateral = debtBefore.collateralBalance.div("1000000000000000000");
        if (debtOncollateral.lt(0)) {
            debtOncollateral = debtOncollateral.abs();
        } else {
            debtOncollateral = BigNumber.from(0);
        }

        await borrowingManager.connect(bob).increaseCollateralBalance(key, collateralAmt.add(debtOncollateral));// +1 seconds
        let debtAfter = (await borrowingManager.getBorrowerDebtsInfo(bob.address))[0];

        expect(debtAfter.estimatedLifeTime).to.be.within(debtBefore.estimatedLifeTime.add(86398), debtBefore.estimatedLifeTime.add(86399));
    });

    it("using external swap with non-whitelisted parameters will fail", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = await time.latest() + 60;

        const swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, USDT_ADDRESS, 0, 0]
        );
        const nonWhitelistedSwapIface = new ethers.utils.Interface(["function nonWhitelistedSwap(bytes calldata wrappedCallData)"]);
        swapData = nonWhitelistedSwapIface.encodeFunctionData("nonWhitelistedSwap", [swap_params]);

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990 //1%

        }
        await expect(borrowingManager.connect(bob).repay(params, deadline)).to.be.reverted;
    });

    it("repay borrowing and restore liquidity using an external swap will be successful", async () => {
        const borrowingKey = await borrowingManager.userBorrowingKeys(bob.address, 0);
        const deadline = await time.latest() + 60;

        const swap_params = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "uint256", "uint256"],
            [WETH_ADDRESS, USDT_ADDRESS, 0, 0]
        );
        swapData = swapIface.encodeFunctionData("swap", [swap_params]);

        const swapParams: ApproveSwapAndPay.SwapParamsStruct = {
            swapTarget: aggregatorMock.address,
            swapAmountInDataIndex: 3,
            maxGasForCall: 0,
            swapData: swapData
        }

        const params: LiquidityBorrowingManager.RepayParamsStruct = {
            isEmergency: false,
            internalSwapPoolfee: 500,
            externalSwap: swapParams,
            borrowingKey: borrowingKey,
            swapSlippageBP1000: 990 //1%

        }
        await borrowingManager.connect(bob).repay(params, deadline);
    });

});

