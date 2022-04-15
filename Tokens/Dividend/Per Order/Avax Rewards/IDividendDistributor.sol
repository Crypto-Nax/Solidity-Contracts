//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution,uint256 _minHoldAmount) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;        
    function claimDividendFor(address shareholder) external;
    function holdAmount() external view returns(uint256);
    function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256);
    function getAccountInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256);
    function updateDividendDistributor(address token, address _router) external;
}
