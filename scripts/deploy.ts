import hardhat, { ethers } from "hardhat";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = hardhat.network.name;

    console.log(`[${network}] deployer address: ${deployer.address}`);
    /// Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    const UNISWAP_V3_QUOTER_V2 = "0x61fFE014bA17989E743c5F6cB21bF9697530B21e";
    const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = await LiquidityBorrowingManager.deploy(
        NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        UNISWAP_V3_QUOTER_V2,
        UNISWAP_V3_FACTORY,
        UNISWAP_V3_POOL_INIT_CODE_HASH
    );
    await borrowingManager.deployed();
    console.log(`LiquidityBorrowingManager  deployed to ${borrowingManager.address}`);
    // await sleep(30000);

    // await hardhat.run("verify:verify", {
    //     address: borrowingManager.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         UNISWAP_V3_QUOTER_V2,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH],
    // });

    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
