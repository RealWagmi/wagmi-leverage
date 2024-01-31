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

    // Kinetix.finance kava
    // https://github.com/kinetixfi/v3-deploy-scripts/blob/main/state.json
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x8dB08eD2b460643974C64BE42087903470Df6a54";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2";
    // const LIGHT_QUOTER_V3 = "0xbd352897CF946E205C80520976F6573b7FF3a734";

    // wagmi kava
    // https://github.com/RealWagmi/v3_core
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xa9aF508A15fc3B75763A9e536505FFE1F884D12C";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B";
    // const LIGHT_QUOTER_V3 = "0xbd352897CF946E205C80520976F6573b7FF3a734";

    // sushi arbitrum
    // https://github.com/sushiswap/v3-periphery/tree/master/deployments
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xF0cBce1942A68BEB3d1b73F0dd86C8DCc363eF49";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e";
    // const LIGHT_QUOTER_V3 = "0xb9235A074C68A046308aEbD7414Fb89e674adEae";

    /// Uniswap Mainnet, Goerli, Arbitrum, Optimism, Polygon
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    // const LIGHT_QUOTER_V3 = "0xb9235A074C68A046308aEbD7414Fb89e674adEae";



    const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    const borrowingManager = await LiquidityBorrowingManager.deploy(
        NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
        LIGHT_QUOTER_V3,
        UNISWAP_V3_FACTORY,
        UNISWAP_V3_POOL_INIT_CODE_HASH
    );
    await borrowingManager.deployed();
    console.log(`LiquidityBorrowingManager  deployed to ${borrowingManager.address}`);
    await sleep(30000);
    const vaultAddress = await borrowingManager.VAULT_ADDRESS();
    console.log(`Vault  deployed to ${vaultAddress}`);

    // await hardhat.run("verify:verify", {
    //     address: borrowingManager.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         LIGHT_QUOTER_V3,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH]
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
