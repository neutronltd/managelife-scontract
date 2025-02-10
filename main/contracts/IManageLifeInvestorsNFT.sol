// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IManageLifeInvestorsNFT {
    function lifeTokenIssuanceRate(uint256 tokenId) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function checkClaimableStakingRewards(uint256 tokenId) external view returns (uint256);
}