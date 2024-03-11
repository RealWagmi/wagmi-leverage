import hardhat, { ethers } from "hardhat";

async function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = hardhat.network.name;

    console.log(`[${network}] deployer address: ${deployer.address}`);

    // const LightQuoterV3Factory = await ethers.getContractFactory("LightQuoterV3");
    // const lightQuoter = await LightQuoterV3Factory.deploy();
    // await lightQuoter.deployed();
    // console.log(`LightQuoterV3  deployed to ${lightQuoter.address}`);
    // await sleep(10000);

    // let UNISWAP_V3_FACTORY_WAGMI = "";
    // let UNISWAP_V3_POOL_INIT_CODE_HASH_WAGMI = "";
    // let UNISWAP_V3_FACTORY_KINETIX = "";
    // let UNISWAP_V3_POOL_INIT_CODE_HASH_KINETIX = "";
    // if (network === "kava") {
    //     UNISWAP_V3_FACTORY_WAGMI = "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B";
    //     UNISWAP_V3_POOL_INIT_CODE_HASH_WAGMI = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    //     UNISWAP_V3_FACTORY_KINETIX = "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2";
    //     UNISWAP_V3_POOL_INIT_CODE_HASH_KINETIX = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // } else if (network === "metis") {
    //     UNISWAP_V3_FACTORY_WAGMI = "0x8112E18a34b63964388a3B2984037d6a2EFE5B8A";
    //     UNISWAP_V3_POOL_INIT_CODE_HASH_WAGMI = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // }

    // const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    // const flashLoanAggregator = await FlashLoanAggregatorFactory.deploy(UNISWAP_V3_FACTORY_WAGMI, UNISWAP_V3_POOL_INIT_CODE_HASH_WAGMI, "wagmi");
    // await flashLoanAggregator.deployed();
    // console.log(`FlashLoanAggregator  deployed to ${flashLoanAggregator.address}`);
    // await sleep(5000);
    // await flashLoanAggregator.addUniswapV3Dex(UNISWAP_V3_FACTORY_KINETIX, UNISWAP_V3_POOL_INIT_CODE_HASH_KINETIX, "kinetix");
    // console.log(`add kinetix to flashLoanAggregator`);

    // Kinetix.finance kava
    // https://github.com/kinetixfi/v3-deploy-scripts/blob/main/state.json
    // const dexname = "kinetix"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x8dB08eD2b460643974C64BE42087903470Df6a54";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2";
    // const LIGHT_QUOTER_V3 = "0xCa4526D9d02A7Bb005d850c2176E8aE30B970149";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x57b647530B718103B05751278C4835B068FDC491";

    // wagmi kava
    // https://github.com/RealWagmi/v3_core
    // const dexname = "wagmi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xa9aF508A15fc3B75763A9e536505FFE1F884D12C";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B";
    // const LIGHT_QUOTER_V3 = "0xCa4526D9d02A7Bb005d850c2176E8aE30B970149";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x57b647530B718103B05751278C4835B068FDC491";

    /// wagmi Metis
    // const dexname ="wagmi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x8112E18a34b63964388a3B2984037d6a2EFE5B8A";
    // const LIGHT_QUOTER_V3 = "0x5A9fd95e3f865d416bb77b49d1Cca8109FcAbfE5";

    /// Uniswap Mainnet, Goerli, Arbitrum, Optimism, Polygon
    // const dexname ="uniswap"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    // const LIGHT_QUOTER_V3 = "0xd878ccBb5126199A3343678eB7D84EF6cf28b217";


    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = await LiquidityBorrowingManager.deploy(
        NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        FLASH_LOAN_AGGREGATOR_ADDRESS,
        LIGHT_QUOTER_V3,
        UNISWAP_V3_FACTORY,
        UNISWAP_V3_POOL_INIT_CODE_HASH
    );
    await borrowingManager.deployed();
    console.log(`LiquidityBorrowingManager  deployed to ${borrowingManager.address}`);
    await sleep(5000);
    const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    const flashLoanAggregator = FlashLoanAggregatorFactory.attach(FLASH_LOAN_AGGREGATOR_ADDRESS);
    await flashLoanAggregator.setWagmiLeverageAddress(borrowingManager.address);
    console.log(`setWagmiLeverageAddress flashLoanAggregator`);

    // await sleep(5000);
    // const PositionEffectivityChart = await ethers.getContractFactory("PositionEffectivityChart");
    // const positionEffectivityChart = await PositionEffectivityChart.deploy(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH);
    // await positionEffectivityChart.deployed();
    // console.log(`PositionEffectivityChart  deployed to ${positionEffectivityChart.address}`);

    await sleep(30000);
    const vaultAddress = await borrowingManager.VAULT_ADDRESS();
    console.log(`Vault  deployed to ${vaultAddress}`);

    // await hardhat.run("verify:verify", {
    //     address: borrowingManager.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         FLASH_LOAN_AGGREGATOR_ADDRESS,
    //         LIGHT_QUOTER_V3,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH]
    // });

    // await hardhat.run("verify:verify", {
    //     address: LIGHT_QUOTER_V3,
    //     constructorArguments: []
    // });

    // await hardhat.run("verify:verify", {
    //     address: FLASH_LOAN_AGGREGATOR_ADDRESS,
    //     constructorArguments: [UNISWAP_V3_FACTORY_WAGMI, UNISWAP_V3_POOL_INIT_CODE_HASH_WAGMI, "wagmi"]
    // });

    // await hardhat.run("verify:verify", {
    //     address: positionEffectivityChart.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH]
    // });

    // await hardhat.run("verify:verify", {
    //     address: vaultAddress,
    //     constructorArguments: []
    // });
    // curl -X GET "https://kavascan.com/api?module=contract&action=verify_via_sourcify&addressHash=${borrowingManager.address}" -H "accept: application/json"

    console.log("done!");
    process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
