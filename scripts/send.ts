import hardhat, { ethers } from "hardhat";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

const config = {
    borrowingManagerAddress: {
        ["kava"]: {
            ["wagmi"]: "0x7bCDC07587f597339735C3D518a054007b73898b",
            ["kinetix"]: "0xb4b3628C4Da9b6C6564D4E14277fFa8b3aE50BD6"
        },

        ["arbitrum"]:
        {
            ["uniswap"]: "0x44f4E18B1D4D8c0517a5163a4a6f33534d50d71e",
            ["sushiswap"]: "0x663bAAC9D162b23aB324b46707CE3dE353405663"
        },

        ["metis"]:
        {
            ["wagmi"]: "0x1bbcE9Fc68E47Cd3E4B6bC3BE64E271bcDb3edf1"
        },

    }
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
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0x04e45aaf", true);//exactInputSingle
    // await sleep(5000);
    // await borrowingManager.setSwapCallToWhitelist("0x8B741B0D79BE80E135C880F7583d427B4D41F015", "0xb858183f", true);//exactInput
    // await sleep(5000);
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
