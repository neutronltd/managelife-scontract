// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MLUSDT is ERC20, ReentrancyGuard, Ownable {
    // 暂停状态
    bool public isPaused = false;

    // 构造函数，初始化代币名称、符号和总供应量
    constructor() ERC20("ML USDT", "MLUSDT") Ownable(msg.sender) {
        // 初始化代币总量为 10 亿，小数点后 18 位
        _mint(msg.sender, 1000000000 * 10**18);
    }

    // 铸造新代币（仅所有者可调用）
    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        _mint(to, amount);
    }

    // 销毁代币（仅所有者可调用）
    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
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

    // 允许所有者暂停或恢复合约
    function togglePause() public onlyOwner {
        isPaused = !isPaused;
        if (isPaused) {
            emit ContractPaused();
        } else {
            emit ContractResumed();
        }
    }

    // 暂停修饰符
    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    // 事件：合约暂停
    event ContractPaused();

    // 事件：合约恢复
    event ContractResumed();
}
