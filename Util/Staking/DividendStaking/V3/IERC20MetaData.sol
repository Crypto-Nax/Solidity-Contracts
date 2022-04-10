// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import './IERC20.sol';

// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v4.5.0

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

