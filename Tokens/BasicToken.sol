// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    constructor(uint startingSupply) ERC20("tokenName", "tokenSymbol") {
        _mint(_msgSender(), startingSupply*10**18);
    }
}
