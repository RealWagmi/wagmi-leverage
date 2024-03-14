import hardhat, { ethers } from "hardhat";

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
    console.log(`LightQuoterV3  deployed to ${lightQuoter.address}`);
    await sleep(10000);
    let dexName0 = "";
    let dexName1 = "";
    let UNISWAP_V3_FACTORY_0 = "";
    let UNISWAP_V3_POOL_INIT_CODE_HASH_0 = "";
    let UNISWAP_V3_FACTORY_1 = "";
    let UNISWAP_V3_POOL_INIT_CODE_HASH_1 = "";
    let AAVE_POOL_ADDRESS_PROVIDER = "";
    if (network === "kava") {
        dexName0 = "wagmi";
        dexName1 = "kinetix";
        UNISWAP_V3_FACTORY_0 = "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B";//wagmi
        UNISWAP_V3_POOL_INIT_CODE_HASH_0 = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";//wagmi
        UNISWAP_V3_FACTORY_1 = "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2";//kinetix
        UNISWAP_V3_POOL_INIT_CODE_HASH_1 = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";//kinetix
    } else if (network === "metis") {
        dexName0 = "wagmi";
        UNISWAP_V3_FACTORY_0 = "0x8112E18a34b63964388a3B2984037d6a2EFE5B8A";
        UNISWAP_V3_POOL_INIT_CODE_HASH_0 = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    } else if (network === "arbitrum") {
        dexName0 = "uniswap";
        dexName1 = "sushi";
        UNISWAP_V3_FACTORY_0 = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
        UNISWAP_V3_POOL_INIT_CODE_HASH_0 = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
        UNISWAP_V3_FACTORY_1 = "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e";
        UNISWAP_V3_POOL_INIT_CODE_HASH_1 = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
        AAVE_POOL_ADDRESS_PROVIDER = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
    }

    const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    const flashLoanAggregator = await FlashLoanAggregatorFactory.deploy(AAVE_POOL_ADDRESS_PROVIDER, UNISWAP_V3_FACTORY_0, UNISWAP_V3_POOL_INIT_CODE_HASH_0, dexName0);
    await flashLoanAggregator.deployed();
    console.log(`[${dexName0}] FlashLoanAggregator  deployed to ${flashLoanAggregator.address}`);
    await sleep(5000);
    await flashLoanAggregator.addUniswapV3Dex(UNISWAP_V3_FACTORY_1, UNISWAP_V3_POOL_INIT_CODE_HASH_1, dexName1);
    console.log(`add [${dexName1}] UniswapV3Dex to flashLoanAggregator`);

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

    // sushi arbitrum
    // https://github.com/sushiswap/v3-periphery/tree/master/deployments
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xF0cBce1942A68BEB3d1b73F0dd86C8DCc363eF49";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e";
    // const LIGHT_QUOTER_V3 = "0xED5162725277a9f836Af4e56D83e14085692f921";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x0BB7f1b8aE4C2C80Ef58c56cab2D07A76fD5C547";

    /// Uniswap Mainnet, Goerli, Arbitrum, Optimism, Polygon
    const dexname = "uniswap"
    const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    const LIGHT_QUOTER_V3 = lightQuoter.address;
    const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;


    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = await LiquidityBorrowingManager.deploy(
        NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        FLASH_LOAN_AGGREGATOR_ADDRESS,
        LIGHT_QUOTER_V3,
        UNISWAP_V3_FACTORY,
        UNISWAP_V3_POOL_INIT_CODE_HASH
    );
    await borrowingManager.deployed();
    console.log(`[${dexname}] LiquidityBorrowingManager  deployed to ${borrowingManager.address}`);
    await sleep(5000);
    // const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    // const flashLoanAggregator = FlashLoanAggregatorFactory.attach(FLASH_LOAN_AGGREGATOR_ADDRESS);
    await flashLoanAggregator.setWagmiLeverageAddress(borrowingManager.address);
    console.log(`setWagmiLeverageAddress flashLoanAggregator`);

    // await sleep(5000);
    // const PositionEffectivityChart = await ethers.getContractFactory("PositionEffectivityChart");
    // const positionEffectivityChart = await PositionEffectivityChart.deploy(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH);
    // await positionEffectivityChart.deployed();
    // console.log(`PositionEffectivityChart  deployed to ${positionEffectivityChart.address}`);


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
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            FLASH_LOAN_AGGREGATOR_ADDRESS,
            LIGHT_QUOTER_V3,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH]
    });

    await hardhat.run("verify:verify", {
        address: lightQuoter.address,
        constructorArguments: []
    });

    await hardhat.run("verify:verify", {
        address: flashLoanAggregator.address,
        constructorArguments: [AAVE_POOL_ADDRESS_PROVIDER, UNISWAP_V3_FACTORY_0, UNISWAP_V3_POOL_INIT_CODE_HASH_0, dexName0]
    });

    // await hardhat.run("verify:verify", {
    //     address: positionEffectivityChart.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH]
    // });

    await hardhat.run("verify:verify", {
        address: vaultAddress,
        constructorArguments: [10000]
    });
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
