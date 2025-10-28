## 介绍

借贷是Defi领域非常重要的模块，Maker、Aave、Compound是当前借贷领域的三巨头。

* Maker: 抵押资产获取稳定币DAI 
* Aave: 加密货币借贷协议 详情
* Compound: 加密货币借贷协议 详情

Pledge 是一个去中心化金融（DeFi）项目，旨在提供固定利率的借贷协议，主要服务于加密资产持有者。Pledge 旨在解决 DeFi 借贷市场中缺乏固定利率和固定期限融资产品的问题。传统的 DeFi 借贷协议通常采用可变利率，主要服务于短期交易者，而 Pledge 则专注于长期融资需求。以下是对 Pledge 项目的详细分析：

## 业务流程

1. 管理员admin创建借贷池子，指定质押borrow token，假设为btc，借贷（lend）token，假设为usdc

   > 假设此时btc和usdc的价格都是 1dollar

2. 匹配期内，alice存入 10 个 usdc， bob 存入 10个btc

3. 管理员进行撮合（settle）， alice 和bob的token锁定住

> 如果有一方的token数量为0，那么settle 失败，此时另一方可以取回自己的token

4. alice可以领取和借出token成比例数量的spToken，后续可以凭此token 领取本金+收益。

5. bob可以领取相应数量的jpToken 。如果pool的质押率为2，那么bob可以借到 10 / 2 = 5 个 usdc。

   > 规定质押率是为了抵抗borrow token价格下跌，导致质押的token无法偿还债务的风险。

6. 借贷正常结束，池子里面的10个btc，管理员卖掉5.5个btc换回5.5个usdc还给alice，剩下4.5个btc还给bob。
7. 如果btc的价格下跌到0.55dollar，管理员进行 **清算**， 卖掉10个btc换回usdc和btc，保证alice的usdc数量不会受损失。

## 测试

 ```bash
 anvil  --fork-url sepolia --fork-block-number 9502032
 forge test --via-ir --rpc-url http://localhost:8545  -vvv
 ```

