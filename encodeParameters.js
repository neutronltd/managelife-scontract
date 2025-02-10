const { ethers } = require("ethers");

// 合约 ABI
const abi = [
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_nftContract",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "_MLIFE",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "_tokenUSDT",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "_tokenUSDC",
                "type": "address"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "constructor"
    }
];

// 构造函数参数
const constructorArgs = [
    "0x1234567890123456789012345678901234567891",
    "0x0000000000000000000000000000000000000001",
    "0x0000000000000000000000000000000000000002",
    "0x0000000000000000000000000000000000000003"
];

// 使用 ethers 解析和编码构造函数参数
const encodedArgs = ethers.utils.defaultAbiCoder.encode(
    abi[0].inputs.map(input => input.type),
    constructorArgs
);

console.log("Encoded Parameters:", encodedArgs);
