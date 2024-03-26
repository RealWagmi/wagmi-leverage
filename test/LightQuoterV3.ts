import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { LightQuoterV3, IQuoterV2 } from "../typechain-types";

describe("LightQuoterV3", function () {
  const UNISWAP_V3_QUOTER_V2 = "0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997";
  const WETH_USDT_500_POOL_ADDRESS = "0xBe141893E4c6AD9272e8C04BAB7E6a10604501a5";
  const WETH_ADDRESS = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8"; // DECIMALS 18  token0
  const USDT_ADDRESS = "0x55d398326f99059fF775485246999027B3197955"; // DECIMALS 6 token1

  let owner: SignerWithAddress;
  let lightQuoter: LightQuoterV3;
  let quoter: IQuoterV2;

  // Utility function to setup the environment before each test
  before(async function () {
    [owner] = await ethers.getSigners();
    quoter = await ethers.getContractAt("IQuoterV2", UNISWAP_V3_QUOTER_V2);
    const LightQuoterV3Factory = await ethers.getContractFactory("LightQuoterV3"); // Assuming there is an ERC20Mock contract
    lightQuoter = await LightQuoterV3Factory.deploy();

  });

  it("LightQuoterV3 should return the same as the QuoterV2", async function () {


    // WETH -> USDT
    let [sqrtPriceX96After, amountOut] = await lightQuoter.quoteExactInputSingle(true, WETH_USDT_500_POOL_ADDRESS, ethers.utils.parseUnits("10", 18));

    let paramsIQuoterV2: IQuoterV2.QuoteExactInputSingleParamsStruct = {
      tokenIn: WETH_ADDRESS,
      tokenOut: USDT_ADDRESS,
      fee: 500,
      amountIn: ethers.utils.parseUnits("10", 18),
      sqrtPriceLimitX96: 0
    };

    let [amountOutIQuoterV2, sqrtPriceX96AfterIQuoterV2, ,] = await quoter.callStatic.quoteExactInputSingle(paramsIQuoterV2);

    expect(sqrtPriceX96After).to.equal(sqrtPriceX96AfterIQuoterV2);
    expect(amountOut).to.equal(amountOutIQuoterV2);


    [sqrtPriceX96After, amountOut] = await lightQuoter.quoteExactInputSingle(false, WETH_USDT_500_POOL_ADDRESS, ethers.utils.parseUnits("1000", 6));

    paramsIQuoterV2 = {
      tokenIn: USDT_ADDRESS,//token1
      tokenOut: WETH_ADDRESS,//token0
      fee: 500,
      amountIn: ethers.utils.parseUnits("1000", 6),
      sqrtPriceLimitX96: 0
    };

    [amountOutIQuoterV2, sqrtPriceX96AfterIQuoterV2, ,] = await quoter.callStatic.quoteExactInputSingle(paramsIQuoterV2);

    expect(sqrtPriceX96After).to.equal(sqrtPriceX96AfterIQuoterV2);
    expect(amountOut).to.equal(amountOutIQuoterV2);

    let amountIn;

    [sqrtPriceX96After, amountIn] = await lightQuoter.quoteExactOutputSingle(false, WETH_USDT_500_POOL_ADDRESS, ethers.utils.parseUnits("10", 18));


    let paramsIQuoterV2Output: IQuoterV2.QuoteExactOutputSingleParamsStruct = {
      tokenIn: USDT_ADDRESS,//token1
      tokenOut: WETH_ADDRESS,//token0
      fee: 500,
      amount: ethers.utils.parseUnits("10", 18),
      sqrtPriceLimitX96: 0
    };

    let amountInIQuoterV2;

    [amountInIQuoterV2, sqrtPriceX96AfterIQuoterV2, ,] = await quoter.callStatic.quoteExactOutputSingle(paramsIQuoterV2Output);

    expect(sqrtPriceX96After).to.equal(sqrtPriceX96AfterIQuoterV2);
    expect(amountIn).to.equal(amountInIQuoterV2);

    [sqrtPriceX96After, amountIn] = await lightQuoter.quoteExactOutputSingle(true, WETH_USDT_500_POOL_ADDRESS, ethers.utils.parseUnits("1000", 6));


    paramsIQuoterV2Output = {
      tokenIn: WETH_ADDRESS,//token0
      tokenOut: USDT_ADDRESS,//token1
      fee: 500,
      amount: ethers.utils.parseUnits("1000", 6),
      sqrtPriceLimitX96: 0
    };

    [amountInIQuoterV2, sqrtPriceX96AfterIQuoterV2, ,] = await quoter.callStatic.quoteExactOutputSingle(paramsIQuoterV2Output);

    expect(sqrtPriceX96After).to.equal(sqrtPriceX96AfterIQuoterV2);
    expect(amountIn).to.equal(amountInIQuoterV2);



  });

});
