import hardhat, { ethers } from "hardhat";
const { constants } = ethers;

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = hardhat.network.name;

    console.log(`[${network}] deployer address: ${deployer.address}`);

    const LightQuoterV3Factory = await ethers.getContractFactory("LightQuoterV3");
    const lightQuoter = await LightQuoterV3Factory.deploy();
    await lightQuoter.deployed();
    console.log(`Pancake LightQuoterV3  deployed to ${lightQuoter.address}`);
    await sleep(10000);

    let PANCAKE_V3_POOL_DEPLOYER = "";
    let PANCAKE_V3_POOL_INIT_CODE_HASH = "";
    let PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "";
    let AAVE_POOL_ADDRESS_PROVIDER = constants.AddressZero;

    let UNISWAP_V3_FACTORY: string[] = [];
    let UNISWAP_V3_POOL_INIT_CODE_HASH: string[] = [];
    let dexNames: string[] = [];

    if (network === "bsc") {
        PANCAKE_V3_POOL_DEPLOYER = "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9";//pancake
        PANCAKE_V3_POOL_INIT_CODE_HASH = "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2";//pancake
        PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364";
        AAVE_POOL_ADDRESS_PROVIDER = "0xff75B6da14FfbbfD355Daf7a2731456b3562Ba6D";

        dexNames = ["uniswap", "sushi"];
        UNISWAP_V3_FACTORY = ["0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7", "0x126555dd55a39328F69400d6aE4F782Bd4C34ABb"]; //uniswap, sushi
        UNISWAP_V3_POOL_INIT_CODE_HASH = ["0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54", "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54"];
    } else if (network === "arbitrum") {
        PANCAKE_V3_POOL_DEPLOYER = "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9";//pancake
        PANCAKE_V3_POOL_INIT_CODE_HASH = "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2";//pancake
        PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364";
        AAVE_POOL_ADDRESS_PROVIDER = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
    }

    // const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    // const flashLoanAggregator = await FlashLoanAggregatorFactory.deploy(AAVE_POOL_ADDRESS_PROVIDER, PANCAKE_V3_POOL_DEPLOYER, PANCAKE_V3_POOL_INIT_CODE_HASH, "pancake");
    // await flashLoanAggregator.deployed();
    // console.log(`[pancake] FlashLoanAggregator  deployed to ${flashLoanAggregator.address}`);

    // for (let i = 0; i < dexNames.length; i++) {
    //     await sleep(5000);
    //     await flashLoanAggregator.addUniswapV3Dex(UNISWAP_V3_FACTORY[i], UNISWAP_V3_POOL_INIT_CODE_HASH[i], dexNames[i]);
    //     console.log(`add [${dexNames[i]}] UniswapV3Dex to flashLoanAggregator`);
    // }

    const LIGHT_QUOTER_V3 = lightQuoter.address;
    const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x9f665a1476Afe20637393b61Dc4ce8c6d1108b0A";


    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = await LiquidityBorrowingManager.deploy(
        PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        FLASH_LOAN_AGGREGATOR_ADDRESS,
        LIGHT_QUOTER_V3,
        PANCAKE_V3_POOL_DEPLOYER,
        PANCAKE_V3_POOL_INIT_CODE_HASH
    );
    await borrowingManager.deployed();
    console.log(`[pancake] LiquidityBorrowingManager  deployed to ${borrowingManager.address}`);
    await sleep(5000);
    const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    const flashLoanAggregator = FlashLoanAggregatorFactory.attach(FLASH_LOAN_AGGREGATOR_ADDRESS);
    await flashLoanAggregator.setWagmiLeverageAddress(borrowingManager.address);
    console.log(`setWagmiLeverageAddress flashLoanAggregator`);

    await sleep(5000);
    const PositionEffectivityChart = await ethers.getContractFactory("PositionEffectivityChart");
    const positionEffectivityChart = await PositionEffectivityChart.deploy(PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS, PANCAKE_V3_POOL_DEPLOYER, PANCAKE_V3_POOL_INIT_CODE_HASH);
    await positionEffectivityChart.deployed();
    console.log(`PositionEffectivityChart  deployed to ${positionEffectivityChart.address}`);

    const vaultAddress = await borrowingManager.VAULT_ADDRESS();
    console.log(`Vault  deployed to ${vaultAddress}`);

    await sleep(5000);

    await borrowingManager.updateSettings(2, ["0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8"]);
    console.log(`operator added`);

    // const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    // const borrowingManager = LiquidityBorrowingManager.attach("0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9");
    // await flashLoanAggregator.setWagmiLeverageAddress("0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9");
    // await sleep(5000);
    // await borrowingManager.updateSettings(4, [flashLoanAggregator.address]);

    // await sleep(30000);


    await hardhat.run("verify:verify", {
        address: borrowingManager.address,
        constructorArguments: [
            PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            FLASH_LOAN_AGGREGATOR_ADDRESS,
            LIGHT_QUOTER_V3,
            PANCAKE_V3_POOL_DEPLOYER,
            PANCAKE_V3_POOL_INIT_CODE_HASH]
    });

    await hardhat.run("verify:verify", {
        address: lightQuoter.address,
        constructorArguments: []
    });

    // await hardhat.run("verify:verify", {
    //     address: flashLoanAggregator.address,
    //     constructorArguments: [AAVE_POOL_ADDRESS_PROVIDER, PANCAKE_V3_POOL_DEPLOYER, PANCAKE_V3_POOL_INIT_CODE_HASH, "pancake"]
    // });

    await hardhat.run("verify:verify", {
        address: positionEffectivityChart.address,
        constructorArguments: [
            PANCAKE_NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            PANCAKE_V3_POOL_DEPLOYER,
            PANCAKE_V3_POOL_INIT_CODE_HASH]
    });

    await hardhat.run("verify:verify", {
        address: vaultAddress,
        constructorArguments: [6900]
    });

    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
