// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILife {
    function mintInvestorsRewards(uint256 _amount, uint256 _tokenId) external;
    function claimableStakingRewards(uint256 tokenId) external view returns (uint256);
    function mint(uint256 _amount) external;
    function burnLifeTokens(uint256 amount) external;
    function claimStakingRewards(uint256 _tokenId) external;
    // 添加 owner 方法的定义
    function owner() external view returns (address);
}