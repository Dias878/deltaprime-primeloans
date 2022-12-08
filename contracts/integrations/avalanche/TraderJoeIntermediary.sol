// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: 49fd65d9a6ea5ddcd283ac4913262e342cf1ad80;
pragma solidity 0.8.17;

import "../UniswapV2Intermediary.sol";
import "../../lib/local/DeploymentConstants.sol";

/**
 * @title TraderJoeIntermediary
 * @dev Contract allows user to swap ERC20 tokens on DEX
 * This implementation uses the TraderJoe DEX
 */
contract TraderJoeIntermediary is UniswapV2Intermediary {

    function getNativeTokenAddress() override internal pure returns (address) {
        return DeploymentConstants.getNativeToken();
    }
}