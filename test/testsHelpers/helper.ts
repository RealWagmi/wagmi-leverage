import { ethers, network } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodePath } from "./path";
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
} from "../../typechain-types";

import { ApproveSwapAndPay } from "../../typechain-types/contracts/LiquidityBorrowingManager";
import { BigNumber } from "@ethersproject/bignumber";
const { constants } = ethers;

export interface Asset {
    tokenAddress: string;
    amount: BigNumber;
}

export interface PositionManagerPosInfo {
    tokenId: BigNumber;
    liquidity: BigNumber;
    amount0: BigNumber;
    amount1: BigNumber;
}

export enum PositionType {
    //  ____Single1____| tisk |________
    // __token0__token1|      |________
    LEFT_OUTRANGE_TOKEN_1,
    //  _______________| tisk |_____Single0______
    //   ______________|      |token0______token1__
    RIGHT_OUTRANGE_TOKEN_0,
    //  _______________| tisk|________
    //  ________ token0|      |token1________
    INRANGE_TOKEN_0_TOKEN_1,
}

export async function addLiquidity(
    posType: PositionType,
    pool: IUniswapV3Pool,
    nonfungiblePositionManager: INonfungiblePositionManager,
    desiredAmount0: BigNumber,
    desiredAmount1: BigNumber,
    range: number,
    signer: SignerWithAddress
): Promise<PositionManagerPosInfo> {
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
        case PositionType.LEFT_OUTRANGE_TOKEN_1: {
            tickUpper = compressed * tickSpacing;
            tickLower = tickUpper - range * tickSpacing;
            amount0 = BigNumber.from(0);
            amount1 = desiredAmount1;
            break;
        }
        case PositionType.RIGHT_OUTRANGE_TOKEN_0: {
            tickLower = (compressed + 1) * tickSpacing;
            tickUpper = tickLower + range * tickSpacing;
            amount1 = BigNumber.from(0);
            amount0 = desiredAmount0;
            break;
        }
        case PositionType.INRANGE_TOKEN_0_TOKEN_1: {
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
        deadline: timestamp + 60,
    };
    const pos = await nonfungiblePositionManager.connect(signer).callStatic.mint(params);
    await nonfungiblePositionManager.connect(signer).mint(params);
    return pos;
}

export async function hackDonor(donorAddress: string, recipients: string[], assets: Asset[]) {
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

export async function maxApprove(signer: SignerWithAddress, spenderAddress: string, erc20tokens: string[]) {
    for (const token of erc20tokens) {
        const erc20: IERC20 = await ethers.getContractAt("IERC20", token);
        await erc20.connect(signer).approve(spenderAddress, constants.MaxUint256);
    }
}

export async function getERC20Balance(tokenAddress: string, account: string): Promise<BigNumber> {
    const TOKEN: IERC20 = await ethers.getContractAt("IERC20", tokenAddress);
    return TOKEN.balanceOf(account);
}

export const compareWithTolerance = async (
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

export async function swap(
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

export async function zeroForOne(tokenA: string, tokenB: string): Promise<boolean> {
    return BigNumber.from(tokenA).lt(BigNumber.from(tokenB));
}
