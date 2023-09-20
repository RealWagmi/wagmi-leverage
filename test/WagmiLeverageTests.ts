import { ethers, network } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodePath } from "./testsHelpers/path";
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
    LiquidityManager
} from "../typechain-types";
import { BigNumber } from "@ethersproject/bignumber";
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
    let snapshot_before: SnapshotRestorer;
    let nonfungiblePositionManager: INonfungiblePositionManager;
    let vaultAddress: string;
    let nftpos: PositionManagerPosInfo[];



    before(async () => {
        console.log("");
        console.log("--------------------------------------");
        console.log("|       pool : WETH-USDT             |");
        console.log("|       position : long              |");
        console.log("|       range : 100 (10 tick spacing)|");
        console.log("|       amount : ~ 3 ETH             |");
        console.log("--------------------------------------");
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
        vaultAddress = await borrowingManager.VAULT_ADDRESS();
        const amountUSDT = ethers.utils.parseUnits("10000", 6);
        const amountWETH = ethers.utils.parseUnits("100", 18);
        await hackDonor(
            DONOR_ADDRESS,
            [owner.address, alice.address, bob.address],
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
        snapshot_before = await takeSnapshot();
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

        const swapParams: LiquidityBorrowingManager.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountDataIndex: 0,
            maxGasForCall: 0,
            swapData: '0x'
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            swapPoolfee: 500,
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

        const swapParams: LiquidityBorrowingManager.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountDataIndex: 0,
            maxGasForCall: 0,
            swapData: '0x'
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            swapPoolfee: 500,
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

        const swapParams: LiquidityBorrowingManager.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountDataIndex: 0,
            maxGasForCall: 0,
            swapData: '0x'
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            swapPoolfee: 500,
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
        const swapPoolFee = 500;
        const slippageBP1000 = 990;//1%
        const deadline = await time.latest() + 60;
        await borrowingManager.connect(bob).repay(borrowingKey, swapPoolFee, slippageBP1000, deadline);
    });

    it("borrowing all liquidity in one transaction (long position WETH) will be successful", async () => {
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

        const swapParams: LiquidityBorrowingManager.SwapParamsStruct = {
            swapTarget: constants.AddressZero,
            swapAmountDataIndex: 0,
            maxGasForCall: 0,
            swapData: '0x'
        }

        const params: LiquidityBorrowingManager.BorrowParamsStruct = {
            swapPoolfee: 500,
            saleToken: USDT_ADDRESS,
            holdToken: WETH_ADDRESS,
            minHoldTokenOut: amountWETH,
            maxCollateral: maxCollateral,//there will be no token sale, there will be no swap
            externalSwap: swapParams,
            loans: loans
        }

        await borrowingManager.connect(bob).borrow(params, deadline);
    });

});

interface Asset {
    tokenAddress: string;
    amount: BigNumber;
}

interface PositionManagerPosInfo {
    tokenId: BigNumber,
    liquidity: BigNumber,
    amount0: BigNumber,
    amount1: BigNumber
}

enum PositionType {
    //  ____Single1____| tisk |________
    // __token0__token1|      |________
    LEFT_OUTRANGE_TOKEN_1,
    //  _______________| tisk |_____Single0______
    //   ______________|      |token0______token1__
    RIGHT_OUTRANGE_TOKEN_0,
    //  _______________| tisk|________
    //  ________ token0|      |token1________
    INRANGE_TOKEN_0_TOKEN_1
}

async function addLiquidity(
    posType: PositionType,
    pool: IUniswapV3Pool,
    nonfungiblePositionManager: INonfungiblePositionManager,
    desiredAmount0: BigNumber,
    desiredAmount1: BigNumber,
    range: number,
    signer: SignerWithAddress): Promise<PositionManagerPosInfo> {

    let tickLower;
    let tickUpper;
    let amount0: BigNumber;
    let amount1: BigNumber;
    const timestamp = await time.latest();
    const token0 = await pool.token0();
    const token1 = await pool.token1();
    const fee = await pool.fee();
    const tickSpacing = await pool.tickSpacing();
    const { tick } = await pool.slot0();
    let compressed = Math.floor(tick / tickSpacing);
    // if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity(In solidity)

    switch (posType) {
        case PositionType.LEFT_OUTRANGE_TOKEN_1:
            {
                tickUpper = compressed * tickSpacing;
                tickLower = tickUpper - (range * tickSpacing);
                amount0 = BigNumber.from(0);
                amount1 = desiredAmount1;
                break;

            }
        case PositionType.RIGHT_OUTRANGE_TOKEN_0:
            {
                tickLower = (compressed + 1) * tickSpacing;
                tickUpper = tickLower + (range * tickSpacing);
                amount1 = BigNumber.from(0);
                amount0 = desiredAmount0;
                break;
            }
        case PositionType.INRANGE_TOKEN_0_TOKEN_1:
            {
                tickUpper = (compressed + (range - range / 2)) * tickSpacing;
                tickLower = (compressed - range / 2) * tickSpacing;
                amount1 = desiredAmount1;
                amount0 = desiredAmount0;
                break;
            }
    }


    const params: INonfungiblePositionManager.MintParamsStruct = {
        token0: token0,
        token1: token1,
        fee: fee,
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: 0,
        amount1Min: 0,
        recipient: signer.address,
        deadline: timestamp + 60
    }
    const pos = await nonfungiblePositionManager.connect(signer).callStatic.mint(params);
    await nonfungiblePositionManager.connect(signer).mint(params);
    return pos;
}

async function hackDonor(donorAddress: string, recipients: string[], assets: Asset[]) {
    const ForceSend = await ethers.getContractFactory("ForceSend");
    let forceSend = await ForceSend.deploy();
    await forceSend.go(donorAddress, { value: ethers.utils.parseUnits("100", "ether") });
    await impersonateAccount(donorAddress);
    let donor = ethers.provider.getSigner(donorAddress);
    for (const asset of assets) {
        const TOKEN: IERC20 = await ethers.getContractAt("IERC20", asset.tokenAddress);
        for (const recipient of recipients) {
            await TOKEN.connect(donor).transfer(recipient, asset.amount);
        }
    }
}

async function maxApprove(signer: SignerWithAddress, spenderAddress: string, erc20tokens: string[]) {
    for (const token of erc20tokens) {
        const erc20: IERC20 = await ethers.getContractAt("IERC20", token);
        await erc20.connect(signer).approve(spenderAddress, constants.MaxUint256);
    }
}

async function getERC20Balance(tokenAddress: string, account: string): Promise<BigNumber> {
    const TOKEN: IERC20 = await ethers.getContractAt("IERC20", tokenAddress);
    return TOKEN.balanceOf(account);
}

const compareWithTolerance = async (
    current: BigNumber,
    expected: BigNumber,
    accuracy: number
): Promise<void> => {
    let accuracyMax = current.toString().length > 1 ? current.toString().length - 1 : 1;
    if (accuracy > accuracyMax) {
        accuracy = accuracyMax;
    }

    const TOLERANCE_MAX = BigNumber.from(10 ** accuracy);
    const TOLERANCE_MIN = TOLERANCE_MAX.sub(1);
    expect(current).to.be.within(
        expected.mul(TOLERANCE_MIN).div(TOLERANCE_MAX),
        expected.mul(TOLERANCE_MAX).div(TOLERANCE_MIN)
    );
};

async function swap(
    fee: number,
    tokenIn: string,
    tokenOut: string,
    amountIn: BigNumber,
    trader: SignerWithAddress,
    router: ISwapRouter
) {
    const TOKENIN: IERC20 = await ethers.getContractAt("IERC20", tokenIn);

    const timestamp = await time.latest();
    await TOKENIN.connect(trader).approve(router.address, amountIn);
    // accmuluate token0 fees
    await router.connect(trader).exactInput({
        recipient: trader.address,
        deadline: timestamp + 10,
        path: encodePath([tokenIn, tokenOut], [fee]),
        amountIn: amountIn,
        amountOutMinimum: 0,
    });

}

async function zeroForOne(
    tokenA: string,
    tokenB: string
): Promise<boolean> {
    return BigNumber.from(tokenA).lt(BigNumber.from(tokenB));
}
