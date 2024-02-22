import hardhat, { ethers } from "hardhat";
import config from "./config";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}


async function main() {
    //const [deployer] = await ethers.getSigners();
    let dexname = "wagmi";

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
    // //metis
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0x04e45aaf", true);//exactInputSingle
    // await sleep(5000);
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0xb858183f", true);//exactInput
    // await sleep(5000);
    // //Open Ocean Exchange Proxy
    // await borrowingManager.setSwapCallToWhitelist("0x6352a56caadC4F1E25CD6c75970Fa768A3304e64", "0x90411a32", true);//swap
    // ====================================================
    // // kava
    // await borrowingManager.setSwapCallToWhitelist("0xB9a14EE1cd3417f3AcC988F61650895151abde24", "0x04e45aaf", true);// SwapRouter02 exactInputSingle
    // await sleep(5000);
    // await borrowingManager.setSwapCallToWhitelist("0xB9a14EE1cd3417f3AcC988F61650895151abde24", "0xb858183f", true);//SwapRouter02 exactInput
    // await sleep(5000);
    // //Open Ocean Exchange Proxy
    // await borrowingManager.setSwapCallToWhitelist("0x6352a56caadC4F1E25CD6c75970Fa768A3304e64", "0x90411a32", true);//swap

    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
