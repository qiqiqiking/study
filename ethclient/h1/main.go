package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

const (
	SepoliaRPC = "https://sepolia.infura.io/v3/118e80e70c934d2c906b15b4e907401c"
)

// QueryBlock 查询指定区块号的区块信息
func QueryBlock(blockNumber *big.Int) (*types.Block, error) {
	client, err := ethclient.Dial(SepoliaRPC)
	if err != nil {
		return nil, fmt.Errorf("连接 Sepolia 失败: %w", err)
	}
	defer client.Close()

	block, err := client.BlockByNumber(context.Background(), blockNumber)
	if err != nil {
		return nil, fmt.Errorf("获取区块失败: %w", err)
	}
	return block, nil
}

// SendETHTransfer 发送 ETH 转账交易
// 参数：
//   - privateKeyHex: 发送方私钥（十六进制字符串，不带 0x）
//   - toAddress: 接收方地址（0x...）
//   - amountWei: 转账金额（单位：wei）
//
// 返回交易哈希（成功）或错误
// SendETHTransfer 使用 EIP-1559 动态费用交易发送 ETH 转账
func SendETHTransfer(privateKeyHex string, toAddress string, amountWei *big.Int) (common.Hash, error) {
	client, err := ethclient.Dial(SepoliaRPC)
	if err != nil {
		return common.Hash{}, fmt.Errorf("连接 Sepolia 失败: %w", err)
	}
	defer client.Close()

	privateKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		return common.Hash{}, fmt.Errorf("私钥格式错误: %w", err)
	}

	publicKeyECDSA, ok := privateKey.Public().(*ecdsa.PublicKey)
	if !ok {
		return common.Hash{}, fmt.Errorf("公钥类型错误")
	}
	fromAddr := crypto.PubkeyToAddress(*publicKeyECDSA)

	nonce, err := client.PendingNonceAt(context.Background(), fromAddr)
	if err != nil {
		return common.Hash{}, fmt.Errorf("获取 nonce 失败: %w", err)
	}

	// 获取建议的 gas 费用（EIP-1559）
	gasTipCap, err := client.SuggestGasTipCap(context.Background())
	if err != nil {
		return common.Hash{}, fmt.Errorf("获取 gasTipCap 失败: %w", err)
	}

	// 获取 base fee（最新区块的 base fee）
	head, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		return common.Hash{}, fmt.Errorf("获取最新区块头失败: %w", err)
	}
	gasFeeCap := new(big.Int).Add(
		head.BaseFee,
		new(big.Int).Mul(gasTipCap, big.NewInt(2)), // 留一点余量
	)

	gasLimit := uint64(21000) // ETH 转账标准 gas
	toAddr := common.HexToAddress(toAddress)

	tx := &types.DynamicFeeTx{
		ChainID:   big.NewInt(11155111), // Sepolia Chain ID
		Nonce:     nonce,
		GasTipCap: gasTipCap,
		GasFeeCap: gasFeeCap,
		Gas:       gasLimit,
		To:        &toAddr,
		Value:     amountWei,
		Data:      nil,
	}

	// 创建签名器
	signer := types.NewLondonSigner(tx.ChainID)
	signedTx, err := types.SignNewTx(privateKey, signer, tx)
	if err != nil {
		return common.Hash{}, fmt.Errorf("签名交易失败: %w", err)
	}

	// ✅ 发送已签名交易
	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		return common.Hash{}, fmt.Errorf("发送交易失败: %w", err)
	}

	return signedTx.Hash(), nil
}

// 示例主函数（可删除或用于测试）
func main() {
	// 示例 1: 查询区块
	blockNum := big.NewInt(4000000)
	block, err := QueryBlock(blockNum)
	if err != nil {
		log.Fatal("查询区块失败:", err)
	}
	fmt.Printf("✅ 区块 %d 查询成功\n", block.Number())
	fmt.Printf("哈希: %s\n", block.Hash().Hex())
	fmt.Printf("时间戳: %d\n", block.Time())
	fmt.Printf("交易数: %d\n", len(block.Transactions()))

	// 示例 2: 发送转账（请先替换私钥和地址！）

	txHash, err := SendETHTransfer(
		"4f0a5941f9e8cca14615c49814b8fd95f4044d03e4d7f7fa01a8fec533f9d6d0",
		"0xc434060c77a741a5a2033c83214279eea33334e6",
		big.NewInt(1e18), // 0.01 ETH
	)
	if err != nil {
		log.Fatal("转账失败:", err)
	}
	fmt.Printf("✅ 交易已发送，哈希: %s\n", txHash.Hex())

}
