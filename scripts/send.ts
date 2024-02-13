import hardhat, { ethers } from "hardhat";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

const config = {
    borrowingManagerAddress: {
        ["kava"]: {
            ["wagmi"]: "0xCc99476805F82e1446541FCb1010269EbC092ae2",
            ["kinetix"]: "0x45861d6700eAFdD9C8cAD21348ecC2a90328F3E1"
        },

        ["arbitrum"]:
        {
            ["uniswap"]: "0x793288e6B1bd67fFC3d31992c54e0a3B2bDd655c",
            ["sushiswap"]: "0x6374e71E15C6c7706237386584EC8c55c97e7bDa"
        },

        ["metis"]:
        {
            ["wagmi"]: "0x3C422982E76261a3eC73363CAcf5C3731e318104"
        },

    }
}


async function main() {
    //const [deployer] = await ethers.getSigners();
    let dexname = "";

    const network = hardhat.network.name as keyof typeof config.borrowingManagerAddress;


    const dex = dexname as keyof typeof config.borrowingManagerAddress[typeof network];
    const borrowingManagerAddress = config.borrowingManagerAddress[network][dex];
    console.log("");
    console.log(`[${network}]  ${dex} LiquidityBorrowingManager : ${borrowingManagerAddress}`);


    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = LiquidityBorrowingManager.attach(borrowingManagerAddress);

    // await borrowingManager.updateSettings(2, [user]);
    // await sleep(5000);
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0x04e45aaf", true);//exactInputSingle
    // await sleep(5000);
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0xb858183f", true);//exactInput
    // //Open Ocean Exchange Proxy
    // await borrowingManager.setSwapCallToWhitelist("0x6352a56caadC4F1E25CD6c75970Fa768A3304e64", "0x90411a32", true);//swap
    // ====================================================

    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
