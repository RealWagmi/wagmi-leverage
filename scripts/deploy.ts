// deploy script for those who know what it does
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
    console.log(`LightQuoterV3  deployed to ${lightQuoter.address}`);
    await sleep(10000);
    let dexNames: string[] = [];
    let V3_FACTORY: string[] = [];
    let V3_POOL_INIT_CODE_HASH: string[] = [];
    let AAVE_POOL_ADDRESS_PROVIDER = constants.AddressZero;
    let borrowingManagerAddresses: string[] = [];
    if (network === "kava") {
        dexNames = ["wagmi", "kinetix"];
        V3_FACTORY = ["0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B", "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2"];
        V3_POOL_INIT_CODE_HASH = [
            "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb",
            "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54",
        ];

        // borrowingManagerAddresses = ["0x496775412549d27A1eC4dDAde02c5c50C50dd8eE", "0xf58a7048b36b2A67dDda4f0E32E76B1081F3AaF0"];
    } else if (network === "metis") {
        dexNames = ["wagmi", "hercules"];
        V3_FACTORY = [
            "0x8112E18a34b63964388a3B2984037d6a2EFE5B8A",
            "0x43AA9b2eD25F972fD8D44fDfb77a4a514eAB4d71", //poolDeployer
        ];
        V3_POOL_INIT_CODE_HASH = [
            "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb",
            "0x6c1bebd370ba84753516bc1393c0d0a6c645856da55f5393ac8ab3d6dbc861d3",
        ];
        // borrowingManagerAddresses = ["0x25a31a36Ff56Bc5570fd09Ac2da062115DAeb54e"];
    } else if (network === "arbitrum") {
        dexNames = ["uniswap", "sushi", "pancake"];
        V3_FACTORY = [
            "0x1F98431c8aD98523631AE4a59f267346ea31F984",
            "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e",
            "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        ];
        V3_POOL_INIT_CODE_HASH = [
            "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54",
            "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54",
            "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2",
        ];
        AAVE_POOL_ADDRESS_PROVIDER = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
        // borrowingManagerAddresses = ["0xda57F8C3466d42D58B505ED9121F348210Ac78A4", "0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1", "0x4a7d1Bd77557461aBa23b74bF41153034524107b"];
    } else if (network === "base") {
        dexNames = ["uniswap", "sushi", "pancake"];
        V3_FACTORY = [
            "0x33128a8fC17869897dcE68Ed026d694621f6FDfD",
            "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        ];
        V3_POOL_INIT_CODE_HASH = [
            "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54",
            "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54",
            "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2",
        ];
        AAVE_POOL_ADDRESS_PROVIDER = "0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D";
        // borrowingManagerAddresses = ["0xda57F8C3466d42D58B505ED9121F348210Ac78A4", "0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1", "0x4a7d1Bd77557461aBa23b74bF41153034524107b"];
    } else if (network === "iotaevm") {
        dexNames = ["wagmi"];
        V3_FACTORY = ["0x01Bd510B2eA106917e711f9a05a42fC162bee2Ac"];
        V3_POOL_INIT_CODE_HASH = ["0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb"];
    } else if (network === "sonic") {
        dexNames = ["wagmi"];
        V3_FACTORY = ["0x56CFC796bC88C9c7e1b38C2b0aF9B7120B079aef"];
        V3_POOL_INIT_CODE_HASH = ["0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb"];
    }

    const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    const flashLoanAggregator = await FlashLoanAggregatorFactory.deploy(
        AAVE_POOL_ADDRESS_PROVIDER,
        V3_FACTORY[0],
        V3_POOL_INIT_CODE_HASH[0],
        dexNames[0]
    );
    await flashLoanAggregator.deployed();
    console.log(`[${dexNames[0]}] FlashLoanAggregator  deployed to ${flashLoanAggregator.address}`);
    await sleep(5000);
    // for (let i = 1; i < dexNames.length; i++) {
    //     await flashLoanAggregator.addUniswapV3Dex(V3_FACTORY[i], V3_POOL_INIT_CODE_HASH[i], dexNames[i]);
    //     await sleep(5000);
    //     console.log(`add [${dexNames[i]}] UniswapV3Dex to flashLoanAggregator`);
    // }
    // for (const element of borrowingManagerAddresses) {
    //     await sleep(10000);
    //     await flashLoanAggregator.setWagmiLeverageAddress(element);
    //     console.log(`[${element}] setWagmiLeverageAddress flashLoanAggregator`);
    //     await sleep(10000);

    //     const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    //     const borrowingManager = LiquidityBorrowingManager.attach(element);

    //     await borrowingManager.updateSettings(4, [flashLoanAggregator.address]);
    //     console.log(`[${element}] updateSettings`);
    // }

    // Kinetix.finance kava
    // https://github.com/kinetixfi/v3-deploy-scripts/blob/main/state.json
    // const dexname = "kinetix"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x8dB08eD2b460643974C64BE42087903470Df6a54";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2";
    // const LIGHT_QUOTER_V3 = "0x1C9B724cBd7683c80226cE35a39F9127950ABb95";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x923e559a12d856f3217b715fE98a7a07CabD6Ed7";

    // wagmi kava
    // https://github.com/RealWagmi/v3_core
    // const dexname = "wagmi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xa9aF508A15fc3B75763A9e536505FFE1F884D12C";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x0e0Ce4D450c705F8a0B6Dd9d5123e3df2787D16B";
    // const LIGHT_QUOTER_V3 = "0x1C9B724cBd7683c80226cE35a39F9127950ABb95";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x923e559a12d856f3217b715fE98a7a07CabD6Ed7";

    /// wagmi Metis
    // const dexname = "wagmi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x8112E18a34b63964388a3B2984037d6a2EFE5B8A";
    // const LIGHT_QUOTER_V3 = lightQuoter.address;
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;

    // sushi arbitrum
    // https://github.com/sushiswap/v3-periphery/tree/master/deployments
    // const dexname = "sushi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xF0cBce1942A68BEB3d1b73F0dd86C8DCc363eF49";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e";
    // const LIGHT_QUOTER_V3 = "0x4948f07aCEF9958eb03f1F46f5A949594f2dA2D9";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x9f665a1476Afe20637393b61Dc4ce8c6d1108b0A";

    // sushi Base
    // https://github.com/sushiswap/v3-periphery/tree/master/deployments
    // const dexname = "sushi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x80C7DD17B01855a6D2347444a0FCC36136a314de";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
    // const LIGHT_QUOTER_V3 = "0x2A3EFD7c2B88dd02b150F7A81825414Db82a7832";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x1bbcE9Fc68E47Cd3E4B6bC3BE64E271bcDb3edf1";

    /// Uniswap Mainnet, Goerli, Arbitrum, Optimism, Polygon
    // const dexname = "uniswap"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    // const LIGHT_QUOTER_V3 = lightQuoter.address;
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;

    /// Uniswap Base
    // const dexname = "uniswap"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
    // const UNISWAP_V3_FACTORY = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD";
    // const LIGHT_QUOTER_V3 = lightQuoter.address;
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;

    // wagmi Base
    // const dexname = "wagmi";
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x8187808B163E7CBAcCc4D0A9B138AE6196ac1f72";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x576A1301B42942537d38FB147895fE83fB418fD4";
    // const LIGHT_QUOTER_V3 = "0x2A3EFD7c2B88dd02b150F7A81825414Db82a7832";
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = "0x1bbcE9Fc68E47Cd3E4B6bC3BE64E271bcDb3edf1";
    // const SWAP_ROUTER_O2 = "0xB5fa77E3929fe198a86Aa40fd6c77886785bCd0e";

    /// wagmi IOTA
    // const dexname = "wagmi"
    // const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x949FDF28F437258E7564a35596b1A99b24F81e4e";
    // const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    // const UNISWAP_V3_FACTORY = "0x01Bd510B2eA106917e711f9a05a42fC162bee2Ac";
    // const LIGHT_QUOTER_V3 = lightQuoter.address;
    // const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;

    // // wagmi Sonic
    const dexname = "wagmi";
    const NONFUNGIBLE_POSITION_MANAGER_ADDRESS = "0x77DcC9b09C6Ae94CDC726540735682A38e18d690";
    const UNISWAP_V3_POOL_INIT_CODE_HASH = "0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb";
    const UNISWAP_V3_FACTORY = "0x56CFC796bC88C9c7e1b38C2b0aF9B7120B079aef";
    const LIGHT_QUOTER_V3 = lightQuoter.address;
    const FLASH_LOAN_AGGREGATOR_ADDRESS = flashLoanAggregator.address;
    const SWAP_ROUTER_O2 = "0x1Ac569879EF7EacB17CC373EF801cDcE4acCdeD5";

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
    //===
    // const FlashLoanAggregatorFactory = await ethers.getContractFactory("FlashLoanAggregator");
    // const flashLoanAggregator = FlashLoanAggregatorFactory.attach(FLASH_LOAN_AGGREGATOR_ADDRESS);
    // await flashLoanAggregator.addUniswapV3Dex(UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH, dexname);
    // await sleep(5000);

    await flashLoanAggregator.setWagmiLeverageAddress(borrowingManager.address);
    console.log(`setWagmiLeverageAddress flashLoanAggregator`);

    // await sleep(5000);
    // const PositionEffectivityChart = await ethers.getContractFactory("PositionEffectivityChart");
    // const positionEffectivityChart = await PositionEffectivityChart.deploy(
    //     NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //     UNISWAP_V3_FACTORY,
    //     UNISWAP_V3_POOL_INIT_CODE_HASH
    // );
    // await positionEffectivityChart.deployed();
    // console.log(`PositionEffectivityChart  deployed to ${positionEffectivityChart.address}`);

    const vaultAddress = await borrowingManager.VAULT_ADDRESS();
    console.log(`Vault  deployed to ${vaultAddress}`);

    await sleep(5000);

    await borrowingManager.updateSettings(2, ["0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8"]);
    console.log(`operator added`);

    await sleep(5000);
    // // base
    //await borrowingManager.setSwapCallToWhitelist("0xDef1C0ded9bec7F1a1670819833240f027b25EfF", true); // matcha by 0x
    //console.log(`matcha by 0x`);

    // Open Ocean Exchange Proxy sonic
    await borrowingManager.setSwapCallToWhitelist("0x6352a56caadC4F1E25CD6c75970Fa768A3304e64", true); //swap
    console.log(`Open Ocean Exchange`);
    await sleep(5000);
    await borrowingManager.setSwapCallToWhitelist(SWAP_ROUTER_O2, true);
    await sleep(5000);
    console.log(`SwapRouter02`);
    await sleep(5000);
    await borrowingManager.updateSettings(1, [69]);
    console.log(`69`);

    // const LiquidityBorrowingManager = await ethers.getContractFactory("LiquidityBorrowingManager");
    // const borrowingManager = LiquidityBorrowingManager.attach("0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9");
    // await flashLoanAggregator.setWagmiLeverageAddress("0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9");
    // await sleep(5000);
    // await borrowingManager.updateSettings(4, [flashLoanAggregator.address]);

    await sleep(30000);

    await hardhat.run("verify:verify", {
        address: borrowingManager.address,
        constructorArguments: [
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            FLASH_LOAN_AGGREGATOR_ADDRESS,
            LIGHT_QUOTER_V3,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH,
        ],
    });
    await sleep(5000);

    await hardhat.run("verify:verify", {
        address: lightQuoter.address,
        constructorArguments: [],
    });
    await sleep(5000);

    await hardhat.run("verify:verify", {
        address: flashLoanAggregator.address,
        constructorArguments: [AAVE_POOL_ADDRESS_PROVIDER, V3_FACTORY[0], V3_POOL_INIT_CODE_HASH[0], dexNames[0]],
    });
    await sleep(5000);

    // await hardhat.run("verify:verify", {
    //     address: positionEffectivityChart.address,
    //     constructorArguments: [
    //         NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
    //         UNISWAP_V3_FACTORY,
    //         UNISWAP_V3_POOL_INIT_CODE_HASH,
    //     ],
    // });
    // await sleep(5000);

    await hardhat.run("verify:verify", {
        address: vaultAddress,
        constructorArguments: [6900],
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
