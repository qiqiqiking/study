// main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// 连接以太坊节点
	rpcURL := os.Getenv("RPC_URL")
	if rpcURL == "" {
		rpcURL = "https://sepolia.infura.io/v3/118e80e70c934d2c906b15b4e907401c"
	}
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		log.Fatal("连接节点失败:", err)
	}
	defer client.Close()

	// 加载私钥
	privateKeyHex := os.Getenv("PRIVATE_KEY")
	if privateKeyHex == "" {
		log.Fatal("请设置 PRIVATE_KEY 环境变量")
	}
	if strings.HasPrefix(privateKeyHex, "0x") {
		privateKeyHex = privateKeyHex[2:]
	}
	privateKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		log.Fatal("私钥无效:", err)
	}

	//创建交易授权器
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		log.Fatal("获取 chain ID 失败:", err)
	}
	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		log.Fatal("创建 auth 失败:", err)
	}
	auth.GasLimit = 300000 // 设置 gas limit
	auth.GasPrice, err = client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatal("获取 gas price 失败:", err)
	}

	//  部署合约
	fmt.Println("正在部署 Counter 合约...")
	address, tx, counter, err := DeployCounter(auth, client)
	if err != nil {
		log.Fatal("部署失败:", err)
	}
	fmt.Printf("部署交易已发送: %s\n", tx.Hash().Hex())

	// 等待交易确认
	receipt, err := bind.WaitMined(context.Background(), client, tx)
	if err != nil {
		log.Fatal("等待部署失败:", err)
	}
	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Fatal("部署交易失败 (revert)")
	}

	fmt.Printf("✅ 合约部署成功！地址: %s\n", address.Hex())

	//  调用 getCount()
	count, err := counter.GetCount(&bind.CallOpts{})
	if err != nil {
		log.Fatal("调用 getCount 失败:", err)
	}
	fmt.Printf("当前 count 值: %s\n", count.String())

	//  调用 increment()
	fmt.Println("正在调用 increment()...")
	tx, err = counter.Increment(auth) // ✅ 复用已有的 auth
	if err != nil {
		log.Fatal("调用 increment 失败:", err)
	}
	fmt.Printf("Increment 交易: %s\n", tx.Hash().Hex())

	receipt, err = bind.WaitMined(context.Background(), client, tx)
	if err != nil {
		log.Fatal("等待 increment 失败:", err)
	}
	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Fatal("increment 交易失败")
	}

	// 再次读取 count
	count, err = counter.GetCount(&bind.CallOpts{})
	if err != nil {
		log.Fatal("再次调用 getCount 失败:", err)
	}
	fmt.Printf("✅ 新的 count 值: %s\n", count.String())
}
