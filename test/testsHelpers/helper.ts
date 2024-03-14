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

import { IApproveSwapAndPay } from "../../typechain-types/contracts/LiquidityBorrowingManager";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
const { constants } = ethers;

import BN from "bn.js";


import { Logger } from "@ethersproject/logger";
const logger = new Logger("bignumber/5.7.0");

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
        const TOKEN: IERC20 = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", asset.tokenAddress) as IERC20;
        for (const recipient of recipients) {
            await TOKEN.connect(donor).transfer(recipient, asset.amount);
        }
    }
}

export async function maxApprove(signer: SignerWithAddress, spenderAddress: string, erc20tokens: string[]) {
    for (const token of erc20tokens) {
        const erc20: IERC20 = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", token) as IERC20;
        await erc20.connect(signer).approve(spenderAddress, constants.MaxUint256);
    }
}

export async function getERC20Balance(tokenAddress: string, account: string): Promise<BigNumber> {
    const TOKEN: IERC20 = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", tokenAddress) as IERC20;
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
    const TOKENIN: IERC20 = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", tokenIn) as IERC20;

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

function toHex(value: string | BN): string {

    // For BN, call on the hex string
    if (typeof (value) !== "string") {
        return toHex(value.toString(16));
    }

    // If negative, prepend the negative sign to the normalized positive value
    if (value[0] === "-") {
        // Strip off the negative sign
        value = value.substring(1);

        // Cannot have multiple negative signs (e.g. "--0x04")
        if (value[0] === "-") { logger.throwArgumentError("invalid hex", "value", value); }

        // Call toHex on the positive component
        value = toHex(value);

        // Do not allow "-0x00"
        if (value === "0x00") { return value; }

        // Negate the value
        return "-" + value;
    }

    // Add a "0x" prefix if missing
    if (value.substring(0, 2) !== "0x") { value = "0x" + value; }

    // Normalize zero
    if (value === "0x") { return "0x00"; }

    // Make the string even length
    if (value.length % 2) { value = "0x0" + value.substring(2); }

    // Trim to smallest even-length string
    while (value.length > 4 && value.substring(0, 4) === "0x00") {
        value = "0x" + value.substring(4);
    }

    return value;
}

function toBigNumber(value: BN): BigNumber {
    return BigNumber.from(toHex(value));
}

function toBN(value: BigNumberish): BN {
    const hex = BigNumber.from(value).toHexString();
    if (hex[0] === "-") {
        return (new BN("-" + hex.substring(3), 16));
    }
    return new BN(hex.substring(2), 16);
}
// https://github.com/dholms/bn-sqrt/blob/main/index.ts
export const sqrt = (num: BN): BN => {
    if (num.lt(new BN(0))) {
        throw new Error("Sqrt only works on non-negtiave inputs")
    }
    if (num.lt(new BN(2))) {
        return num
    }

    const smallCand = sqrt(num.shrn(2)).shln(1)
    const largeCand = smallCand.add(new BN(1))

    if (largeCand.mul(largeCand).gt(num)) {
        return smallCand
    } else {
        return largeCand
    }
}

export async function getSqrtPriceLimitX96(
    pool: IUniswapV3Pool,
    tokenA: string,
    tokenB: string,
    slip: string
): Promise<BigNumber> {

    const zeroForSaleToken = BigNumber.from(tokenA).lt(BigNumber.from(tokenB));
    let { sqrtPriceX96 } = await pool.slot0();
    const slipBP = ethers.utils.parseUnits(slip, 2);
    let deviation = sqrtPriceX96.pow(2).mul(slipBP).div(10000);
    if (zeroForSaleToken) {
        sqrtPriceX96 = sqrtPriceX96.pow(2).add(deviation);
    } else {
        sqrtPriceX96 = sqrtPriceX96.pow(2).sub(deviation);
    }
    sqrtPriceX96 = toBigNumber(sqrt(toBN(sqrtPriceX96)));
    return sqrtPriceX96;
}

export async function zeroForOne(tokenA: string, tokenB: string): Promise<boolean> {
    return BigNumber.from(tokenA).lt(BigNumber.from(tokenB));
}
