// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.23;
import "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IFlashLoanAggregator.sol";
import "./interfaces/IWagmiLeverageFlashCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/abstract/ILiquidityManager.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./vendor0.8/uniswap/FullMath.sol";
import "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes } from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";
import { IAToken } from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import { IFlashLoanSimpleReceiver } from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";

// import "hardhat/console.sol";

/**
 * @title FlashLoanAggregator
 * @dev This contract serves as an aggregator for flash loans from different protocols.
 * It defines various data structures and modifiers used in the contract.
 */
contract FlashLoanAggregator is
    Ownable,
    IFlashLoanAggregator,
    IFlashLoanSimpleReceiver,
    IUniswapV3FlashCallback
{
    using TransferHelper for address;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    enum Protocol {
        UNKNOWN,
        UNISWAP,
        AAVE
    }
    struct Debt {
        Protocol protocol;
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

    IPoolAddressesProvider public override ADDRESSES_PROVIDER;
    IPool public override POOL;

    UniswapV3Identifier[] public uniswapV3Dexes;
    mapping(bytes32 => bool) public uniswapDexIsExists;
    mapping(address => bool) public wagmiLeverageContracts;
    /**
     * @dev Modifier to restrict access to only contracts registered as Wagmi Leverage contracts.
     */
    modifier onlyWagmiLeverage() {
        require(wagmiLeverageContracts[msg.sender], "IC");
        _;
    }
    /**
     * @dev Modifier to check if the provided index is within the range of the uniswapV3Dexes array.
     * @param indx The index to check.
     */
    modifier correctIndx(uint256 indx) {
        require(uniswapV3Dexes.length > indx, "II");
        _;
    }
    event UniswapV3DexAdded(address factoryV3, bytes32 initCodeHash, string name);
    event UniswapV3DexChanged(address factoryV3, bytes32 initCodeHash, string name);

    error CollectedAmountIsNotEnough(uint256 desiredAmount, uint256 collectedAmount);
    error FlashLoanZeroLiquidity(address pool);
    error FlashLoanAaveZeroLiquidity();

    /**
     * @dev Constructor function that initializes the contract with a Uniswap V3 Dex.
     * @param factoryV3 The address of the Uniswap V3 factory.
     * @param initCodeHash The init code hash of the Uniswap V3 factory.
     * @param name The name of the Uniswap V3 Dex.
     */
    constructor(
        address aaveAddressProvider, //https://docs.aave.com/developers/deployed-contracts/v3-mainnet
        address factoryV3,
        bytes32 initCodeHash,
        string memory name
    ) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        _addUniswapV3Dex(factoryV3, initCodeHash, nameHash, name);
        if (aaveAddressProvider != address(0)) {
            ADDRESSES_PROVIDER = IPoolAddressesProvider(aaveAddressProvider);
            POOL = IPool(ADDRESSES_PROVIDER.getPool());
        }
    }

    /**
     * @dev Initializes the Aave protocol by setting the Aave address provider and the Aave pool.
     * @param aaveAddressProvider The address of the Aave address provider contract.
     * @notice This function can only be called by the contract owner.
     * @notice The Aave address provider must not be the zero address.
     * @notice The Aave pool must not have been initialized before.
     */
    function initAave(address aaveAddressProvider) external onlyOwner {
        require(aaveAddressProvider != address(0));
        require(address(POOL) == address(0));
        ADDRESSES_PROVIDER = IPoolAddressesProvider(aaveAddressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    /**
     * @dev Sets the address of the Wagmi Leverage contract.
     * @param _wagmiLeverageAddress The address of the Wagmi Leverage contract.
     */
    function setWagmiLeverageAddress(address _wagmiLeverageAddress) external onlyOwner {
        wagmiLeverageContracts[_wagmiLeverageAddress] = true;
    }

    /**
     * @dev Adds a Uniswap V3 DEX to the FlashLoanAggregator contract.
     * @param factoryV3 The address of the Uniswap V3 factory contract.
     * @param initCodeHash The init code hash of the Uniswap V3 factory contract.
     * @param name The name of the Uniswap V3 DEX.
     * Requirements:
     * - Only the contract owner can call this function.
     * - The Uniswap V3 DEX with the given name must not already exist.
     */
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

    /**
     * @dev Edits the Uniswap V3 DEX configuration at the specified index.
     * @param enabled Whether the DEX is enabled or not.
     * @param factoryV3 The address of the Uniswap V3 factory contract.
     * @param initCodeHash The init code hash of the Uniswap V3 pair contract.
     * @param indx The index of the DEX in the `uniswapV3Dexes` array.
     * Requirements:
     * - The caller must be the contract owner.
     * - The `indx` must be a valid index in the `uniswapV3Dexes` array.
     */
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

    /**
     * @dev Executes a flash loan by interacting with different protocols based on the specified route.
     * @param amount The amount of the flash loan.
     * @param data Additional data for the flash loan.
     * @notice Only callable by the `onlyWagmiLeverage` modifier.
     * @notice Supports flash loans from Uniswap and Aave protocols.
     * @notice Reverts if the specified route is not supported.
     */
    function flashLoan(uint256 amount, bytes calldata data) external onlyWagmiLeverage {
        ILiquidityManager.CallbackData memory decodedData = abi.decode(
            data,
            (ILiquidityManager.CallbackData)
        );
        ILiquidityManager.FlashLoanParams[] memory flashLoanParams = decodedData
            .routes
            .flashLoanParams;

        require(flashLoanParams.length > 0, "FLP");
        Protocol protocol = Protocol(flashLoanParams[0].protocol);

        Debt[] memory debts = new Debt[](flashLoanParams.length);

        if (protocol == Protocol.UNISWAP) {
            address pool = _getUniswapV3Pool(decodedData.saleToken, flashLoanParams[0].data);

            (uint256 flashAmount0, uint256 flashAmount1) = _maxUniPoolFlashAmt(
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
                        debts: debts,
                        originData: data
                    })
                )
            );
        } else if (protocol == Protocol.AAVE) {
            require(address(POOL) != address(0), "Aave not initialized");
            uint256 maxAmount = checkAaveFlashReserve(decodedData.saleToken);
            if (maxAmount == 0) {
                revert FlashLoanAaveZeroLiquidity();
            }

            POOL.flashLoanSimple(
                address(this),
                decodedData.saleToken,
                amount > maxAmount ? maxAmount : amount,
                abi.encode(
                    CallbackDataExt({
                        recipient: msg.sender,
                        amount: amount,
                        currentIndex: 0,
                        prevBalance: 0,
                        debts: debts,
                        originData: data
                    })
                ),
                0
            );
        } else {
            revert("UFP");
        }
    }

    function checkAaveFlashReserve(address asset) public view returns (uint256 amount) {
        DataTypes.ReserveData memory reserve = POOL.getReserveData(asset);
        uint128 premium = POOL.FLASHLOAN_PREMIUM_TOTAL();
        DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;
        if (
            premium > 100 ||
            configuration.getPaused() ||
            !configuration.getActive() ||
            !configuration.getFlashLoanEnabled()
        ) {
            return 0;
        }

        amount = asset.getBalanceOf(reserve.aTokenAddress);
    }

    function executeOperation(
        address /*asset*/,
        uint256 /*amount*/,
        uint256 premium,
        address /*initiator*/,
        bytes calldata data
    ) external override returns (bool) {
        _excuteCallback(premium, data);
        return true;
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        _excuteCallback(fee0 + fee1, data);
    }

    /**
     * @dev Calculates the maximum flash loan amount for a given token and pool.
     * @param token The address of the token.
     * @param pool The address of the Uniswap V3 pool.
     * @param amount The desired flash loan amount.
     * @return flashAmount0 The maximum amount of token0 that can be borrowed.
     * @return flashAmount1 The maximum amount of token1 that can be borrowed.
     * @dev This function checks the liquidity of the pool and the balance of the token in the pool.
     * If the pool has zero liquidity or the token balance is zero, it reverts with an error.
     * Otherwise, it calculates the maximum flash loan amount based on the available token balance.
     * If `zeroForSaleToken` is true, `flashAmount0` will be set to `flashAmt`, otherwise `flashAmount1` will be set to `flashAmt`.
     */
    function _maxUniPoolFlashAmt(
        address token,
        address pool,
        uint256 amount
    ) private view returns (uint256 flashAmount0, uint256 flashAmount1) {
        uint256 flashAmt = token.getBalanceOf(pool);
        if (flashAmt == 0 || IUniswapV3Pool(pool).liquidity() == 0) {
            revert FlashLoanZeroLiquidity(pool);
        }
        address token0 = IUniswapV3Pool(pool).token0();
        bool zeroForSaleToken = token0 == token;

        flashAmt = flashAmt > amount ? amount : flashAmt;
        (flashAmount0, flashAmount1) = zeroForSaleToken
            ? (flashAmt, uint256(0))
            : (uint256(0), flashAmt);
    }

    /**
     * @dev Retrieves the address of a Uniswap V3 pool based on the provided parameters.
     * @param saleToken The address of the token being sold.
     * @param leverageData The encoded data containing the pool fee tiers, second token address, and DEX index.
     * @return pool The address of the Uniswap V3 pool.
     * @dev This function decodes the `leverageData` and retrieves the necessary information to compute the pool address.
     * @dev It checks if the specified DEX is enabled before computing the pool address.
     * @dev The pool address is computed using the `computePoolAddress` function with the provided parameters.
     */
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

        pool = _computePoolAddress(
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
    function _computePoolAddress(
        uint24 fee,
        address tokenA,
        address tokenB,
        address factoryV3,
        bytes32 initCodeHash
    ) private pure returns (address pool) {
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

    function _tryApprove(address token, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, address(POOL), amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _aaveFlashApprove(address token, uint256 amount) internal {
        if (!_tryApprove(token, amount)) {
            require(_tryApprove(token, 0), "AFA0");
            require(_tryApprove(token, amount), "AFA");
        }
    }

    /**
     * @dev Private function to repay flash loans after execution.
     * This function handles the repayment of multiple debts that arose during flash loan operations.
     * It ensures the correct amounts are repaid to the corresponding creditors, and performs approval
     * for token transfer if needed. The function supports both AAVE and UNISWAP protocols and is designed
     * to work with arrays of debt structs which contain information about debts from various protocols.
     *
     * If the last protocol used in the series of flash loans was AAVE, the function approves the AAVE
     * lending pool to pull the repayment amount and settles UNISWAP debts directly by transferring funds.
     *
     * Conversely, if the last protocol was UNISWAP, the function directly transfers the needed funds to
     * settle the debt and handles the AAVE debt separately by performing a token approval.
     *
     * Any protocols other than AAVE or UNISWAP will cause the transaction to revert.
     *
     * @param lastProto The protocol used in the last taken flash loan.
     * @param token The ERC20 token address that was used for the flash loans.
     * @param lastAmtWithPremium The cumulative flash loan amount including any premiums/fees from the last flash loan taken.
     * @param debts An array of Debt structs containing details about each individual debt accrued through the flash loan sequence.
     */
    function _repayFlashLoans(
        Protocol lastProto,
        address token,
        uint256 lastAmtWithPremium,
        Debt[] memory debts
    ) private {
        // Check if the last flash loan was taken from the AAVE protocol
        if (lastProto == Protocol.AAVE) {
            // Approve the AAVE contract to pull the repayment amount including premiums
            _aaveFlashApprove(token, lastAmtWithPremium);
            // Iterate over the array of debts to process repayments
            // if we have already processed the AAVE protocol we do not expect it
            for (uint256 i = 0; i < debts.length; ) {
                Debt memory debt = debts[i];
                // Exit loop if creditor address is zero indicating no more debts
                if (debt.creditor == address(0)) {
                    break;
                }
                // Handle UNISWAP debt repayment by transferring tokens directly to creditor
                if (debt.protocol == Protocol.UNISWAP) {
                    token.safeTransfer(debt.creditor, debt.body + debt.interest);
                } else {
                    revert("REA");
                }
                unchecked {
                    ++i;
                }
            }
            // Check if the last flash loan was taken from the UNISWAP protocol
        } else if (lastProto == Protocol.UNISWAP) {
            // Directly transfer the loan amount plus premium to the sender for final UNISWAP loan settlement
            token.safeTransfer(msg.sender, lastAmtWithPremium);

            for (uint256 i = 0; i < debts.length; ) {
                Debt memory debt = debts[i];
                if (debt.creditor == address(0)) {
                    break;
                }
                if (debt.protocol == Protocol.AAVE) {
                    // Approve repayment for AAVE debts
                    _aaveFlashApprove(token, debt.body + debt.interest);
                } else if (debt.protocol == Protocol.UNISWAP) {
                    // Transfer tokens directly for UNISWAP debts
                    token.safeTransfer(debt.creditor, debt.body + debt.interest);
                } else {
                    revert("REU");
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            revert("RE UFP");
        }
    }

    /**
     * @dev Internal function that executes a flash loan callback.
     * It processes the received data, performs checks based on the protocol,
     * and handles repayment of debts or initiation of subsequent flash loans.
     *
     * The function decodes the `data` parameter to extract the callback details and then,
     * depending on the state of the flash loan process (e.g., if this is an intermediary step
     * in a sequence of flash loans, or the final callback), it either performs the necessary payouts
     * and calls the user's callback function, or it encodes new data and triggers another flash loan.
     *
     * Additionally, the function enforces security by requiring that it is called only by the expected
     * sources (like a specific Uniswap pool or the AAVE lending pool) according to the loan protocol used.
     * It supports different protocols like Uniswap or AAVE for the execution of flash loans.
     *
     * @param premium The fee or interest amount associated with the flash loan.
     * @param data Encoded data containing all relevant information to perform callbacks and repayments.
     */
    function _excuteCallback(uint256 premium, bytes calldata data) internal {
        // Decode the extended callback data structure
        CallbackDataExt memory decodedDataExt = abi.decode(data, (CallbackDataExt));
        // Decode the original callback data sent by the user
        ILiquidityManager.CallbackData memory decodedData = abi.decode(
            decodedDataExt.originData,
            (ILiquidityManager.CallbackData)
        );
        // Extract the current flash loan parameters from the route provided in the callback data
        ILiquidityManager.FlashLoanParams memory flashParams = decodedData.routes.flashLoanParams[
            decodedDataExt.currentIndex
        ];
        // Determine the protocol used for the current flash loan
        Protocol protocol = Protocol(flashParams.protocol);

        if (protocol == Protocol.UNISWAP) {
            require(
                msg.sender == _getUniswapV3Pool(decodedData.saleToken, flashParams.data),
                "IPC"
            );
        } else if (protocol == Protocol.AAVE) {
            require(msg.sender == address(POOL), "IPC");
        } else {
            revert("IPC UFP");
        }

        uint256 flashBalance = decodedData.saleToken.getBalance();
        // Check if enough funds were received to cover the loan or if this is the last loan step
        if (
            flashBalance >= decodedDataExt.amount ||
            decodedDataExt.currentIndex == decodedData.routes.flashLoanParams.length - 1
        ) {
            // Compute total interest including premiums of intermediate steps
            uint256 interest = premium;
            // Process recorded debt information for each protocol involved in the loan series
            uint256 debtsLength = decodedDataExt.debts.length;
            for (uint256 i = 0; i < debtsLength; ) {
                // Terminate early if we hit an empty creditor slot
                if (decodedDataExt.debts[i].creditor == address(0)) {
                    debtsLength = i;
                    break;
                }
                unchecked {
                    // Accumulate interest from each debt
                    interest += decodedDataExt.debts[i].interest;
                    ++i;
                }
            }
            // Transfer the flashBalance to the recipient
            decodedData.saleToken.safeTransfer(decodedDataExt.recipient, flashBalance);
            // Invoke the WagmiLeverage callback function with updated parameters
            IWagmiLeverageFlashCallback(decodedDataExt.recipient).wagmiLeverageFlashCallback(
                flashBalance,
                interest,
                decodedDataExt.originData
            );

            uint256 lastPayment = flashBalance - decodedDataExt.prevBalance + premium;
            // Repay all flash loans that have been taken out across different protocols
            _repayFlashLoans(protocol, decodedData.saleToken, lastPayment, decodedDataExt.debts);
        } else {
            // If not enough funds, prepare for the next flash loan in the series
            uint256 nextIndx = decodedDataExt.currentIndex + 1;
            // Record the current debt for the ongoing protocol
            decodedDataExt.debts[decodedDataExt.currentIndex] = Debt({
                protocol: protocol,
                creditor: msg.sender,
                body: flashBalance - decodedDataExt.prevBalance,
                interest: premium
            });
            // Encode data for the next flash loan callback
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
            // Set up next flash loan params
            flashParams = decodedData.routes.flashLoanParams[nextIndx];
            protocol = Protocol(flashParams.protocol);
            // Trigger the next flash loan based on the protocol
            if (protocol == Protocol.UNISWAP) {
                address pool = _getUniswapV3Pool(decodedData.saleToken, flashParams.data);

                (uint256 flashAmount0, uint256 flashAmount1) = _maxUniPoolFlashAmt(
                    decodedData.saleToken,
                    pool,
                    decodedDataExt.amount - flashBalance
                );

                IUniswapV3Pool(pool).flash(address(this), flashAmount0, flashAmount1, nextData);
            } else if (protocol == Protocol.AAVE) {
                uint256 maxAmount = checkAaveFlashReserve(decodedData.saleToken);
                if (maxAmount == 0) {
                    revert FlashLoanAaveZeroLiquidity();
                }
                uint256 amount = decodedDataExt.amount - flashBalance;

                POOL.flashLoanSimple(
                    address(this),
                    decodedData.saleToken,
                    amount > maxAmount ? maxAmount : amount,
                    nextData,
                    0
                );
            } else {
                revert("UFP");
            }
        }
    }
}
