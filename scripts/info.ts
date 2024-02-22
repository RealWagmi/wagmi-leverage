import hardhat, { ethers } from "hardhat";
import config from "./config";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}


async function main() {
    //const [deployer] = await ethers.getSigners();
    const dexnames = ["wagmi", "kinetix"];
    const user = "";


    const network = hardhat.network.name as keyof typeof config.borrowingManagerAddress;
    for (let dexname of dexnames) {

        const dex = dexname as keyof typeof config.borrowingManagerAddress[typeof network];
        const borrowingManagerAddress = config.borrowingManagerAddress[network][dex];
        console.log("");
        console.log(`[${network}]  ${dex} LiquidityBorrowingManager : ${borrowingManagerAddress}`);


        const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
        const borrowingManager = LiquidityBorrowingManager.attach(borrowingManagerAddress);

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
