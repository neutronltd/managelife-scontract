// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MLUSDC is ERC20, ReentrancyGuard, Ownable {
    constructor() ERC20("ML USDC", "MLUSDC") Ownable(msg.sender) {
        _mint(msg.sender, 1000000000 * 10**18); // 初始化代币总量为 10 亿，小数点后 18 位
    }

    // 铸造新代币
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // 销毁代币
    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    // 重写 transfer 函数，加入防重入和暂停保护
    function transfer(address to, uint256 amount) public override nonReentrant whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    // 重写 transferFrom 函数，加入防重入和暂停保护
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override nonReentrant whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    // 重写 approve 函数，加入防重入和暂停保护
    function approve(address spender, uint256 amount) public override nonReentrant whenNotPaused returns (bool) {
        return super.approve(spender, amount);
    }

    // 允许Owner暂停或恢复合约
    bool public isPaused = false;

    function togglePause() public onlyOwner {
        isPaused = !isPaused;
    }

    modifier whenNotPaused {
        require(!isPaused, "Contract is paused");
        _;
    }
}
