import hardhat, { ethers } from "hardhat";
import config from "./config";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}


async function main() {
    //const [deployer] = await ethers.getSigners();
    let dexname = "pancakeswap";

    const network = hardhat.network.name as keyof typeof config.borrowingManagerAddress;


    const dex = dexname as keyof typeof config.borrowingManagerAddress[typeof network];
    const borrowingManagerAddress = config.borrowingManagerAddress[network][dex];
    console.log("");
    console.log(`[${network}]  ${dex} LiquidityBorrowingManager : ${borrowingManagerAddress}`);


    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = LiquidityBorrowingManager.attach(borrowingManagerAddress);


    // const operator = "";
    // await borrowingManager.updateSettings(2, [operator]);
    // await sleep(5000);
    //bsc
    await borrowingManager.setSwapCallToWhitelist("0xDef1C0ded9bec7F1a1670819833240f027b25EfF", true);//matcha
    await sleep(5000);
    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
