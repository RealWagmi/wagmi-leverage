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
    const dexnames = ["wagmi", "kinetix"];
    const user = "0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8";// George's address


    const network = hardhat.network.name as keyof typeof config.borrowingManagerAddress;
    for (let dexname of dexnames) {

        const dex = dexname as keyof typeof config.borrowingManagerAddress[typeof network];
        const borrowingManagerAddress = config.borrowingManagerAddress[network][dex];
        console.log("");
        console.log(`[${network}]  ${dex} LiquidityBorrowingManager : ${borrowingManagerAddress}`);


        const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
        const borrowingManager = LiquidityBorrowingManager.attach(borrowingManagerAddress);

        // await borrowingManager.updateSettings(2, [user]);
        // await sleep(5000);
        // ====================================================

        const borrowerNum = (await borrowingManager.getBorrowerDebtsCount(user)).toNumber();

        console.log("number of positions:", borrowerNum.toString());
        if (borrowerNum === 0) {
            continue;
        }
        const borrowerInfo = await borrowingManager.getBorrowerDebtsInfo(user);
        //console.log(require('util').inspect(borrowerInfo, true, 3));

        const Erc20 = await ethers.getContractFactory("ERC20");

        await sleep(500);
        const borrowerKeys = (await borrowingManager.getBorrowingKeysForBorrower(user)).map((key) => {
            return {
                key: key.toString()
            }
        });

        //console.table(borrowerKeys);

        const info = await borrowerInfo.reduce(async (accP: Promise<any[]>, cur, index) => {
            let acc = await accP;
            const holdToken = Erc20.attach(cur.info.holdToken);
            const saleToken = Erc20.attach(cur.info.saleToken);
            const decimals = await holdToken.decimals();
            await sleep(50);
            const holdTokenSymbol = await holdToken.symbol();
            await sleep(50);
            const saleTokenSymbol = await saleToken.symbol();
            await sleep(50);

            const info = {
                key: borrowerKeys[index].key,
                saleToken: saleTokenSymbol,
                holdToken: holdTokenSymbol,
                borrowedAmount: ethers.utils.formatUnits(cur.info.borrowedAmount, decimals),
                // collateralBalance: ethers.utils.formatUnits(cur.collateralBalance, decimals + 18),
                estimatedLifeTime: cur.estimatedLifeTime.toString(),
                loans: await cur.loans.reduce(async (accP: Promise<any[]>, cur) => {
                    let acc = await accP;
                    return [
                        ...acc,
                        cur.toString(),
                    ];
                }, Promise.resolve([]))
            };

            return { ...acc, [index]: info };
        }, Promise.resolve([]));


        console.table(info);
    }



    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
