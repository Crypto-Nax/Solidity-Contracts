// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    constructor(uint startingSupply, string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(_msgSender(), startingSupply*10**18);
    }
}
