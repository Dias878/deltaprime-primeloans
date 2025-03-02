// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: bdee015765a0dd3731205df659aae576d57dd473;
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "../../ReentrancyGuardKeccak.sol";
import "../../lib/SolvencyMethods.sol";
import "../../interfaces/facets/avalanche/IYieldYak.sol";
import "../../OnlyOwnerOrInsolvent.sol";

import {DiamondStorageLib} from "../../lib/DiamondStorageLib.sol";
import "../../interfaces/IWrappedNativeToken.sol";

// TODO: Check STATUS (tokenManager) of Vault tokens before allowing to stake
//This path is updated during deployment
import "../../lib/local/DeploymentConstants.sol";

contract YieldYakFacet is ReentrancyGuardKeccak, SolvencyMethods, OnlyOwnerOrInsolvent {
    using TransferHelper for address payable;
    using TransferHelper for address;

    // Staking Vaults tokens
    address private constant YY_AAVE_AVAX = 0xaAc0F2d0630d1D09ab2B5A400412a4840B866d95;
    address private constant YY_PTP_sAVAX = 0xb8f531c0d3c53B1760bcb7F57d87762Fd25c4977;
    address private constant YY_GLP = 0x9f637540149f922145c06e1aa3f38dcDc32Aff5C;

    // Staking Vaults LPs
    address private constant YY_PNG_AVAX_USDC_LP = 0xC0cd58661b68e10b49D3Bec4bC5E44e7A7c20656;
    address private constant YY_PNG_AVAX_ETH_LP = 0xFCD2050E213cC54db2c9c99632AC870574FbC261;
    address private constant YY_TJ_AVAX_USDC_LP = 0xDEf94a13fF31FB6363f1e03bF18fe0F59Db83BBC;
    address private constant YY_TJ_AVAX_ETH_LP = 0x5219558ee591b030E075892acc41334A1694fd8A;
    address private constant YY_TJ_AVAX_sAVAX_LP = 0x22EDe03f1115666CF05a4bAfafaEe8F43D42cD56;

    // Tokens
    address private constant SAVAX_TOKEN = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
    address private constant AVAX_TOKEN = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address private constant GLP_TOKEN = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
    // Older version of stakedGLP token (without decimals() that YieldYak uses
    address private constant sGLP_TOKEN = 0x5643F4b25E36478eE1E90418d5343cb6591BcB9d;
    // LPs
    address private constant PNG_AVAX_USDC_LP = 0x0e0100Ab771E9288e0Aa97e11557E6654C3a9665;
    address private constant PNG_AVAX_ETH_LP = 0x7c05d54fc5CB6e4Ad87c6f5db3b807C94bB89c52;

    address private constant TJ_AVAX_USDC_LP = 0xf4003F4efBE8691B60249E6afbD307aBE7758adb;
    address private constant TJ_AVAX_ETH_LP = 0xFE15c2695F1F920da45C30AAE47d11dE51007AF9;
    address private constant TJ_AVAX_sAVAX_LP = 0x4b946c91C2B1a7d7C40FB3C130CdfBaf8389094d;

    // ----- STAKE -----

    /**
        * Stakes AVAX in Yield Yak protocol
        * @dev This function uses the redstone-evm-connector
        * @param amount amount of AVAX to be staked
    **/
    function stakeAVAXYak(uint256 amount) public onlyOwner nonReentrant recalculateAssetsExposure remainsSolvent {
        require(amount > 0, "Cannot stake 0 tokens");
        amount = Math.min(IWrappedNativeToken(AVAX_TOKEN).balanceOf(address(this)), amount);
        IERC20Metadata yrtToken = IERC20Metadata(YY_AAVE_AVAX);
        uint256 initialYRTBalance = yrtToken.balanceOf(address(this));

        IWrappedNativeToken(AVAX_TOKEN).withdraw(amount);
        IYieldYak(YY_AAVE_AVAX).deposit{value: amount}();

        DiamondStorageLib.addOwnedAsset("YY_AAVE_AVAX", YY_AAVE_AVAX);

        emit Staked(
            msg.sender,
            "AVAX",
            YY_AAVE_AVAX,
            amount,
            yrtToken.balanceOf(address(this)) - initialYRTBalance,
            block.timestamp
        );
    }

    /**
       * Stakes sAVAX in Yield Yak protocol
       * @dev This function uses the redstone-evm-connector
       * @param amount amount of sAVAX to be staked
    **/
    function stakeSAVAXYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
            tokenAddress: SAVAX_TOKEN,
            vaultAddress: YY_PTP_sAVAX,
            tokenSymbol: "sAVAX",
            vaultTokenSymbol: "YY_PTP_sAVAX",
            amount: amount
        }));
    }

    /**
       * Stakes GLP in Yield Yak protocol
       * @dev This function uses the redstone-evm-connector
       * @param amount amount of sAVAX to be staked
    **/
    function stakeGLPYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        // Extra approve for the stakedGLP contract that is being used to transfer fsGLP
        sGLP_TOKEN.safeApprove(YY_GLP, 0);
        sGLP_TOKEN.safeApprove(YY_GLP, amount);
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: GLP_TOKEN,
        vaultAddress: YY_GLP,
        tokenSymbol: "GLP",
        vaultTokenSymbol: "YY_GLP",
        amount: amount
        }));
    }

    /**
      * Stakes PNG_AVAX_USDC_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of PNG_AVAX_USDC_LP to be staked
    **/
    function stakePNGAVAXUSDCYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: PNG_AVAX_USDC_LP,
        vaultAddress: YY_PNG_AVAX_USDC_LP,
        tokenSymbol: "PNG_AVAX_USDC_LP",
        vaultTokenSymbol: "YY_PNG_AVAX_USDC_LP",
        amount: amount
        }));
    }

    /**
      * Stakes PNG_AVAX_ETH_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of PNG_AVAX_ETH_LP to be staked
    **/
    function stakePNGAVAXETHYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: PNG_AVAX_ETH_LP,
        vaultAddress: YY_PNG_AVAX_ETH_LP,
        tokenSymbol: "PNG_AVAX_ETH_LP",
        vaultTokenSymbol: "YY_PNG_AVAX_ETH_LP",
        amount: amount
        }));
    }

    /**
      * Stakes TJ_AVAX_USDC in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_USDC to be staked
    **/
    function stakeTJAVAXUSDCYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_USDC_LP,
        vaultAddress: YY_TJ_AVAX_USDC_LP,
        tokenSymbol: "TJ_AVAX_USDC_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_USDC_LP",
        amount: amount
        }));
    }

    /**
      * Stakes TJ_AVAX_ETH_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_ETH_LP to be staked
    **/
    function stakeTJAVAXETHYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_ETH_LP,
        vaultAddress: YY_TJ_AVAX_ETH_LP,
        tokenSymbol: "TJ_AVAX_ETH_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_ETH_LP",
        amount: amount
        }));
    }

    /**
      * Stakes TJ_AVAX_sAVAX_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_sAVAX_LP to be staked
    **/
    function stakeTJAVAXSAVAXYak(uint256 amount) public onlyOwner nonReentrant remainsSolvent {
        _stakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_sAVAX_LP,
        vaultAddress: YY_TJ_AVAX_sAVAX_LP,
        tokenSymbol: "TJ_AVAX_sAVAX_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_sAVAX_LP",
        amount: amount
        }));
    }

    // ----- UNSTAKE -----


    //TODO: make common method for unstaking single assets

    /**
        * Unstakes AVAX from Yield Yak protocol
        * @dev This function uses the redstone-evm-connector
        * @param amount amount of AVAX to be unstaked
    **/
    function unstakeAVAXYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant recalculateAssetsExposure {
        IYieldYak yakStakingContract = IYieldYak(YY_AAVE_AVAX);
        uint256 initialDepositTokenBalance = address(this).balance;

        amount = Math.min(yakStakingContract.balanceOf(address(this)), amount);

        yakStakingContract.withdraw(amount);

        if(yakStakingContract.balanceOf(address(this)) == 0) {
            DiamondStorageLib.removeOwnedAsset("YY_AAVE_AVAX");
        }

        uint256 depositTokenBalanceAfterWithdrawal = address(this).balance;

        IWrappedNativeToken(AVAX_TOKEN).deposit{value: address(this).balance}();

        if(IERC20(AVAX_TOKEN).balanceOf(address(this)) > 0) {
            DiamondStorageLib.addOwnedAsset("AVAX", AVAX_TOKEN);
        }

        emit Unstaked(
            msg.sender,
            "AVAX",
            YY_AAVE_AVAX,
            depositTokenBalanceAfterWithdrawal - initialDepositTokenBalance,
            amount,
            block.timestamp
        );
    }

    /**
    * Unstakes sAVAX from Yield Yak protocol
    * @dev This function uses the redstone-evm-connector
        * @param amount amount of sAVAX to be unstaked
    **/
    function unstakeSAVAXYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: SAVAX_TOKEN,
        vaultAddress: YY_PTP_sAVAX,
        tokenSymbol: "sAVAX",
        vaultTokenSymbol: "YY_PTP_sAVAX",
        amount: amount
        }));
    }

    /**
    * Unstakes GLP from Yield Yak protocol
    * @dev This function uses the redstone-evm-connector
        * @param amount amount of sAVAX to be unstaked
    **/
    function unstakeGLPYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: GLP_TOKEN,
        vaultAddress: YY_GLP,
        tokenSymbol: "GLP",
        vaultTokenSymbol: "YY_GLP",
        amount: amount
        }));
    }

    /**
      * Unstakes PNG_AVAX_USDC_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of PNG_AVAX_USDC_LP to be staked
    **/
    function unstakePNGAVAXUSDCYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: PNG_AVAX_USDC_LP,
        vaultAddress: YY_PNG_AVAX_USDC_LP,
        tokenSymbol: "PNG_AVAX_USDC_LP",
        vaultTokenSymbol: "YY_PNG_AVAX_USDC_LP",
        amount: amount
        }));
    }

    /**
      * Unstakes PNG_AVAX_ETH_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of PNG_AVAX_ETH_LP to be unstaked
    **/
    function unstakePNGAVAXETHYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: PNG_AVAX_ETH_LP,
        vaultAddress: YY_PNG_AVAX_ETH_LP,
        tokenSymbol: "PNG_AVAX_ETH_LP",
        vaultTokenSymbol: "YY_PNG_AVAX_ETH_LP",
        amount: amount
        }));
    }

    /**
      * Unstakes TJ_AVAX_USDC in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_USDC to be unstaked
    **/
    function unstakeTJAVAXUSDCYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_USDC_LP,
        vaultAddress: YY_TJ_AVAX_USDC_LP,
        tokenSymbol: "TJ_AVAX_USDC_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_USDC_LP",
        amount: amount
        }));
    }

    /**
      * Unstakes TJ_AVAX_ETH_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_ETH_LP to be unstaked
    **/
    function unstakeTJAVAXETHYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_ETH_LP,
        vaultAddress: YY_TJ_AVAX_ETH_LP,
        tokenSymbol: "TJ_AVAX_ETH_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_ETH_LP",
        amount: amount
        }));
    }

    /**
      * Unstakes TJ_AVAX_sAVAX_LP in Yield Yak protocol
      * @dev This function uses the redstone-evm-connector
      * @param amount amount of TJ_AVAX_sAVAX_LP to be unstaked
    **/
    function unstakeTJAVAXSAVAXYak(uint256 amount) public onlyOwnerOrInsolvent nonReentrant {
        _unstakeTokenYY(IYieldYak.YYStakingDetails({
        tokenAddress: TJ_AVAX_sAVAX_LP,
        vaultAddress: YY_TJ_AVAX_sAVAX_LP,
        tokenSymbol: "TJ_AVAX_sAVAX_LP",
        vaultTokenSymbol: "YY_TJ_AVAX_sAVAX_LP",
        amount: amount
        }));
    }

    // ----- PRIVATE METHODS -----

    /**
      * Stakes {stakingDetails.tokenAddress} token in the YieldYak protocol
      * @dev This function uses the redstone-evm-connector
      * @param stakingDetails IYieldYak.YYStakingDetails staking details
    **/
    function _stakeTokenYY(IYieldYak.YYStakingDetails memory stakingDetails) private recalculateAssetsExposure {
        ITokenManager tokenManager = DeploymentConstants.getTokenManager();
        IERC20Metadata yrtToken = IERC20Metadata(stakingDetails.vaultAddress);
        uint256 initialYRTBalance = yrtToken.balanceOf(address(this));

        stakingDetails.amount = Math.min(IERC20Metadata(stakingDetails.tokenAddress).balanceOf(address(this)), stakingDetails.amount);
        require(stakingDetails.amount > 0, "Cannot stake 0 tokens");
        // _ACTIVE = 2
        require(tokenManager.tokenToStatus(stakingDetails.tokenAddress) == 2, "Token not supported");
        require(tokenManager.tokenToStatus(stakingDetails.vaultAddress) == 2, "Vault token not supported");

        stakingDetails.tokenAddress.safeApprove(stakingDetails.vaultAddress, 0);
        stakingDetails.tokenAddress.safeApprove(stakingDetails.vaultAddress, stakingDetails.amount);
        IYieldYak(stakingDetails.vaultAddress).deposit(stakingDetails.amount);

        // Add/remove owned tokens
        DiamondStorageLib.addOwnedAsset(stakingDetails.vaultTokenSymbol, stakingDetails.vaultAddress);
        if(IERC20(stakingDetails.tokenAddress).balanceOf(address(this)) == 0) {
            DiamondStorageLib.removeOwnedAsset(stakingDetails.tokenSymbol);
        }

        emit Staked(
            msg.sender,
            stakingDetails.tokenSymbol,
            stakingDetails.vaultAddress,
            stakingDetails.amount,
            yrtToken.balanceOf(address(this)) - initialYRTBalance,
            block.timestamp);
    }

    /**
      * Unstakes {stakingDetails.tokenAddress} token in the YieldYak protocol
      * @dev This function uses the redstone-evm-connector
      * @param stakingDetails IYieldYak.YYStakingDetails staking details
    **/
    function _unstakeTokenYY(IYieldYak.YYStakingDetails memory stakingDetails) private recalculateAssetsExposure {
        IYieldYak vaultContract = IYieldYak(stakingDetails.vaultAddress);
        IERC20Metadata depositToken = IERC20Metadata(stakingDetails.tokenAddress);
        uint256 initialDepositTokenBalance = depositToken.balanceOf(address(this));
        stakingDetails.amount = Math.min(vaultContract.balanceOf(address(this)), stakingDetails.amount);

        vaultContract.withdraw(stakingDetails.amount);

        // Add/remove owned tokens
        DiamondStorageLib.addOwnedAsset(stakingDetails.tokenSymbol, stakingDetails.tokenAddress);
        if(vaultContract.balanceOf(address(this)) == 0) {
            DiamondStorageLib.removeOwnedAsset(stakingDetails.vaultTokenSymbol);
        }

        emit Unstaked(
            msg.sender,
            stakingDetails.tokenSymbol,
            stakingDetails.vaultAddress,
            depositToken.balanceOf(address(this)) - initialDepositTokenBalance,
            stakingDetails.amount,
            block.timestamp);
    }


    modifier onlyOwner() {
        DiamondStorageLib.enforceIsContractOwner();
        _;
    }

    /* ========== RECEIVE AVAX FUNCTION ========== */
    receive() external payable {}

    /**
        * @dev emitted when user stakes an asset
        * @param user the address executing staking
        * @param asset the asset that was staked
        * @param vault address of the vault token
        * @param depositTokenAmount how much of deposit token was staked
        * @param receiptTokenAmount how much of receipt token was received
        * @param timestamp of staking
    **/
    event Staked(address indexed user, bytes32 indexed asset, address indexed vault, uint256 depositTokenAmount, uint256 receiptTokenAmount, uint256 timestamp);

    /**
        * @dev emitted when user unstakes an asset
        * @param user the address executing unstaking
        * @param vault address of the vault token
        * @param asset the asset that was unstaked
        * @param depositTokenAmount how much deposit token was received
        * @param receiptTokenAmount how much receipt token was unstaked
        * @param timestamp of unstaking
    **/
    event Unstaked(address indexed user, bytes32 indexed asset, address indexed vault, uint256 depositTokenAmount, uint256 receiptTokenAmount, uint256 timestamp);
}