// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface IFactory {
    event PairCreated(address indexed token0, address indexed token1, address liquidityPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address liquidityPair);
    function createPair(address tokenA, address tokenB) external returns (address liquidityPair);
}
