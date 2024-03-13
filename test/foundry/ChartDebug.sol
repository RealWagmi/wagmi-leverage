// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";

import { PositionEffectivityChart } from "contracts/PositionEffectivityChart.sol";
import { HelperContract } from "../testsHelpers/HelperContract.sol";

import { console } from "forge-std/console.sol";

contract ChartDebug is Test, HelperContract {
    address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS =
        0xA7E119Cf6c8f5Be29Ca82611752463f0fFcb1B02;
    address constant UNISWAP_V3_FACTORY = 0x8112E18a34b63964388a3B2984037d6a2EFE5B8A;
    bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    PositionEffectivityChart chartContract;

    function setUp() public {
        vm.createSelectFork("metis", 13598785);
        vm.label(address(this), "ChartDebug");
        vm.label(address(NONFUNGIBLE_POSITION_MANAGER_ADDRESS), "NONFUNGIBLE_POSITION_MANAGER");

        chartContract = new PositionEffectivityChart(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POOL_INIT_CODE_HASH
        );
    }

    // function test_chart() public view {
    //     PositionEffectivityChart.LoanInfo[] memory loans = new PositionEffectivityChart.LoanInfo[](
    //         1
    //     );
    //     loans[0] = PositionEffectivityChart.LoanInfo({
    //         liquidity: 259095985768043040667,
    //         tokenId: 149
    //     });
    //     (
    //         PositionEffectivityChart.LoansData[] memory loansChartData,
    //         PositionEffectivityChart.Chart[2] memory aggressiveModeProfitLine,
    //         PositionEffectivityChart.Chart[] memory chart
    //     ) = chartContract.createChart(false, loans, 50, 50);
    //     for (uint256 i = 0; i < loansChartData.length; i++) {
    //         console.log("amount:", loansChartData[i].amount);
    //         console.log("minPrice:", loansChartData[i].minPrice);
    //         console.log("maxPrice:", loansChartData[i].maxPrice);
    //     }

    //     for (uint256 i = 0; i < aggressiveModeProfitLine.length; i++) {
    //         console.log("price0:", aggressiveModeProfitLine[i].x);
    //         console.logInt(aggressiveModeProfitLine[i].y);
    //     }
    //     for (uint256 i = 0; i < chart.length; i++) {
    //         console.log("{x:", chart[i].x);
    //         console.log(",y:");
    //         console.logInt(chart[i].y);
    //         console.log("},");
    //     }
    // }
}
