// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.23;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFlashLoanAggregator.sol";
import "./interfaces/IWagmiLeverageFlashCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/abstract/ILiquidityManager.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./vendor0.8/uniswap/FullMath.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

// import "hardhat/console.sol";

contract FlashLoanAggregator is Ownable, IFlashLoanAggregator, IUniswapV3FlashCallback {
    using TransferHelper for address;

    enum Protocol {
        UNKNOWN,
        UNISWAP,
        AAVE
    }
    struct Debt {
        address creditor;
        uint256 body;
        uint256 interest;
    }

    struct UniswapV3Identifier {
        bool enabled;
        address factoryV3;
        bytes32 initCodeHash;
        string name;
    }

    struct CallbackDataExt {
        address recipient;
        uint256 currentIndex;
        uint256 amount;
        uint256 prevBalance;
        Debt[] debts;
        bytes originData;
    }

    UniswapV3Identifier[] public uniswapV3Dexes;
    mapping(bytes32 => bool) public uniswapDexIsExists;
    mapping(address => bool) public wagmiLeverageContracts;

    modifier onlyWagmiLeverage() {
        require(wagmiLeverageContracts[msg.sender], "IC");
        _;
    }

    modifier correctIndx(uint256 indx) {
        require(uniswapV3Dexes.length > indx, "II");
        _;
    }
    event UniswapV3DexAdded(address factoryV3, bytes32 initCodeHash, string name);
    event UniswapV3DexChanged(address factoryV3, bytes32 initCodeHash, string name);

    error CollectedAmountIsNotEnough(uint256 desiredAmount, uint256 collectedAmount);
    error FlashLoanZeroLiquidity(address pool);

    constructor(address factoryV3, bytes32 initCodeHash, string memory name) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        _addUniswapV3Dex(factoryV3, initCodeHash, nameHash, name);
    }

    function setWagmiLeverageAddress(address _wagmiLeverageAddress) external onlyOwner {
        wagmiLeverageContracts[_wagmiLeverageAddress] = true;
    }

    function addUniswapV3Dex(
        address factoryV3,
        bytes32 initCodeHash,
        string calldata name
    ) external onlyOwner {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        require(!uniswapDexIsExists[nameHash], "DE");
        _addUniswapV3Dex(factoryV3, initCodeHash, nameHash, name);
    }

    function _addUniswapV3Dex(
        address factoryV3,
        bytes32 initCodeHash,
        bytes32 nameHash,
        string memory name
    ) private {
        uniswapV3Dexes.push(
            UniswapV3Identifier({
                enabled: true,
                factoryV3: factoryV3,
                initCodeHash: initCodeHash,
                name: name
            })
        );
        uniswapDexIsExists[nameHash] = true;
        emit UniswapV3DexAdded(factoryV3, initCodeHash, name);
    }

    function editUniswapV3Dex(
        bool enabled,
        address factoryV3,
        bytes32 initCodeHash,
        uint256 indx
    ) external correctIndx(indx) onlyOwner {
        UniswapV3Identifier storage dex = uniswapV3Dexes[indx];
        dex.enabled = enabled;
        dex.factoryV3 = factoryV3;
        dex.initCodeHash = initCodeHash;
        emit UniswapV3DexChanged(factoryV3, initCodeHash, dex.name);
    }

    function flashLoan(uint256 amount, bytes memory data) external onlyWagmiLeverage {
        ILiquidityManager.CallbackData memory decodedData = abi.decode(
            data,
            (ILiquidityManager.CallbackData)
        );
        ILiquidityManager.FlashLoanParams[] memory flashLoanParams = decodedData
            .routes
            .flashLoanParams;

        require(flashLoanParams.length > 0, "FLP");
        Protocol protocol = Protocol(flashLoanParams[0].protocol);

        if (protocol == Protocol.UNISWAP) {
            address pool = _getUniswapV3Pool(decodedData.saleToken, flashLoanParams[0].data);

            (uint256 flashAmount0, uint256 flashAmount1) = _maxUniPoolFlashAmt(
                decodedData.zeroForSaleToken,
                decodedData.saleToken,
                pool,
                amount
            );

            IUniswapV3Pool(pool).flash(
                address(this),
                flashAmount0,
                flashAmount1,
                abi.encode(
                    CallbackDataExt({
                        recipient: msg.sender,
                        amount: amount,
                        currentIndex: 0,
                        prevBalance: 0,
                        debts: new Debt[](flashLoanParams.length),
                        originData: data
                    })
                )
            );
        } else if (protocol == Protocol.AAVE) {
            revert("AAVE NOT SUPPORTED YET");
        } else {
            revert("UFP");
        }
    }

    // //aave flashLoanSimple
    // function executeOperation(
    //     address /*asset*/,
    //     uint256 /*amount*/,
    //     uint256 /*premium*/,
    //     address /*initiator*/,
    //     bytes calldata params
    // ) external returns (bool) {
    //     (
    //         uint256 poolIndex,
    //         address[] memory targets,
    //         bytes[] memory execData,
    //         uint256[] memory values
    //     ) = abi.decode(params, (uint256, address[], bytes[], uint256[]));
    //     require(msg.sender == pools[poolIndex], "callback not allowed");
    //     execute(targets, execData, values);

    //     return true;
    // }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        CallbackDataExt memory decodedDataExt = abi.decode(data, (CallbackDataExt));
        ILiquidityManager.CallbackData memory decodedData = abi.decode(
            decodedDataExt.originData,
            (ILiquidityManager.CallbackData)
        );
        ILiquidityManager.FlashLoanParams memory flashParams = decodedData.routes.flashLoanParams[
            decodedDataExt.currentIndex
        ];
        address pool = _getUniswapV3Pool(decodedData.saleToken, flashParams.data);
        require(msg.sender == pool, "IPC");
        uint256 flashBalance = decodedData.saleToken.getBalance();
        if (flashBalance >= decodedDataExt.amount) {
            uint256 interest = decodedData.zeroForSaleToken ? fee0 : fee1;
            uint256 debtsLength = decodedDataExt.debts.length;
            for (uint256 i = 0; i < debtsLength; ) {
                if (decodedDataExt.debts[i].creditor == address(0)) {
                    debtsLength = i;
                    break;
                }
                unchecked {
                    interest += decodedDataExt.debts[i].interest;
                    ++i;
                }
            }

            decodedData.saleToken.safeTransfer(decodedDataExt.recipient, decodedDataExt.amount);
            IWagmiLeverageFlashCallback(decodedDataExt.recipient).wagmiLeverageFlashCallback(
                decodedDataExt.amount,
                interest,
                decodedDataExt.originData
            );
            decodedData.saleToken.safeTransfer(
                msg.sender,
                flashBalance -
                    decodedDataExt.prevBalance +
                    (decodedData.zeroForSaleToken ? fee0 : fee1)
            );
            for (uint256 i = 0; i < debtsLength; ) {
                Debt memory debt = decodedDataExt.debts[i];
                decodedData.saleToken.safeTransfer(debt.creditor, debt.body + debt.interest);
                unchecked {
                    ++i;
                }
            }
        } else {
            if (decodedDataExt.currentIndex == decodedData.routes.flashLoanParams.length) {
                revert CollectedAmountIsNotEnough(decodedDataExt.amount, flashBalance);
            }
            decodedDataExt.debts[decodedDataExt.currentIndex] = Debt({
                creditor: msg.sender,
                body: flashBalance - decodedDataExt.prevBalance,
                interest: decodedData.zeroForSaleToken ? fee0 : fee1
            });
            uint256 nextIndx = decodedDataExt.currentIndex + 1;
            bytes memory nextData = abi.encode(
                CallbackDataExt({
                    recipient: decodedDataExt.recipient,
                    amount: decodedDataExt.amount,
                    currentIndex: nextIndx,
                    prevBalance: flashBalance,
                    debts: decodedDataExt.debts,
                    originData: decodedDataExt.originData
                })
            );

            flashParams = decodedData.routes.flashLoanParams[nextIndx];
            Protocol protocol = Protocol(flashParams.protocol);

            if (protocol == Protocol.UNISWAP) {
                pool = _getUniswapV3Pool(decodedData.saleToken, flashParams.data);

                (uint256 flashAmount0, uint256 flashAmount1) = _maxUniPoolFlashAmt(
                    decodedData.zeroForSaleToken,
                    decodedData.saleToken,
                    pool,
                    decodedDataExt.amount - flashBalance
                );

                IUniswapV3Pool(pool).flash(address(this), flashAmount0, flashAmount1, nextData);
            } else if (protocol == Protocol.AAVE) {
                revert("AAVE NOT SUPPORTED YET");
            } else {
                revert("UFP");
            }
        }
    }

    function _maxUniPoolFlashAmt(
        bool zeroForSaleToken,
        address token,
        address pool,
        uint256 amount
    ) private view returns (uint256 flashAmount0, uint256 flashAmount1) {
        uint256 flashAmt = token.getBalanceOf(pool);
        if (flashAmt == 0 || IUniswapV3Pool(pool).liquidity() == 0) {
            revert FlashLoanZeroLiquidity(pool);
        }
        flashAmt = flashAmt > amount ? amount : flashAmt;
        (flashAmount0, flashAmount1) = zeroForSaleToken
            ? (flashAmt, uint256(0))
            : (uint256(0), flashAmt);
    }

    function _getUniswapV3Pool(
        address saleToken,
        bytes memory leverageData
    ) private view returns (address pool) {
        (uint24 poolfeeTiers, address secondToken, uint256 dexIndx) = abi.decode(
            leverageData,
            (uint24, address, uint256)
        );
        UniswapV3Identifier memory dex = uniswapV3Dexes[dexIndx];
        require(dex.enabled, "DXE");

        pool = computePoolAddress(
            poolfeeTiers,
            saleToken,
            secondToken,
            dex.factoryV3,
            dex.initCodeHash
        );
    }

    /**
     * @dev Computes the address of a Uniswap V3 pool based on the provided parameters.
     * Not applicable for the zkSync.
     *
     * This function calculates the address of a Uniswap V3 pool contract using the token addresses and fee.
     * It follows the same logic as Uniswap's pool initialization process.
     *
     * @param fee The fee level of the pool.
     * @param tokenA The address of one of the tokens in the pair.
     * @param tokenB The address of the other token in the pair.
     * @param factoryV3 The address of the Uniswap V3 factory contract.
     * @param initCodeHash The hash of the pool initialization code.
     * @return pool The computed address of the Uniswap V3 pool.
     */
    function computePoolAddress(
        uint24 fee,
        address tokenA,
        address tokenB,
        address factoryV3,
        bytes32 initCodeHash
    ) public pure returns (address pool) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryV3,
                            keccak256(abi.encode(tokenA, tokenB, fee)),
                            initCodeHash
                        )
                    )
                )
            )
        );
    }
}
