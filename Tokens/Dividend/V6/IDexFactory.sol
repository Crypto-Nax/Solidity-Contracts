//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
interface IDEXFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}