// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {multiSignature} from "../src/multiSignature/multiSignature.sol";
import {DebtToken} from "../src/pledge/DebtToken.sol";
import {console} from "forge-std/console.sol";
import {BscPledgeOracle}  from "../src/pledge/BscPledgeOracle.sol";
import {PledgePool} from "../src/pledge/PledgePool.sol";
import {USDC} from "../src/mock/USDC.sol";
import {BTC} from "../src/mock/BTC.sol";

import {IUniswapV2Router02} from "../src/interface/IUniswapV2Router02.sol";
// import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
// import {IWETH} from "../src/interface/IWETH.sol";
// import {WETH} from "../src/mock/WETH.sol";
import {console} from "forge-std/console.sol";

contract PldgeTest is Test {
  // swap
  BTC public btc;
  USDC public usdc;
  IUniswapV2Router02 public swapRouter;
  address constant routerAddr = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

  // pledge
  multiSignature public signs;
  DebtToken public spToken;
  DebtToken public jpToken;
  BscPledgeOracle  public oracle;
  PledgePool public pools;
  address pledgeFee = makeAddr("pledgeFee");

  // 3 owner
  address tom = makeAddr("tom");
  address bob = makeAddr("bob");
  address alice = makeAddr("alice");

  // someone not owner
  address outer = makeAddr("outer");

  function setUp() public {
    tom = makeAddr("tom");
    bob = makeAddr("bob");
    alice = makeAddr("alice");
    outer = makeAddr("outer");

    vm.deal(tom, 100 ether);
    vm.deal(alice, 100 ether);
    vm.deal(bob, 100 ether);
    vm.deal(outer, 100 ether);

    btc = new BTC();
    usdc = new USDC();

    usdc.transfer(alice, 10 * 10**18);
    btc.transfer(bob, 10 * 10**18);

    swapRouter = IUniswapV2Router02(routerAddr);
    btc.approve(address(swapRouter), 10000 ether);
    usdc.approve(address(swapRouter), 10000 ether);

    address[] memory owners = new address[](3);
    owners[0] = tom;
    owners[1] = alice;
    owners[2] = bob;
    signs = new multiSignature(owners, 2);
    spToken = new DebtToken("SpToken", "SP", address(signs));
    jpToken = new DebtToken("jpToken", "JP", address(signs));
    oracle = new BscPledgeOracle(address(signs));

    approve(address(oracle));
    oracle.setPrice(address(usdc), 10**4);
    oracle.setPrice(address(btc), 10**4);

    pools = new PledgePool(
      address(oracle), 
      address(swapRouter), 
      payable(pledgeFee), 
      address(signs)
    );

    // create a pool 
    approve(address(pools));
    uint256 _settleTime = block.timestamp + 60;
    uint256 _endTime = block.timestamp + 120;
    uint64 _interestRate = 10 ** 6; // 1%
    uint256 _maxSupply = 100000 * 10 **18; 
    uint256 _martgageRate = 2 * 10**8;
    address _lendToken = address(usdc);
    address _borrowToken = address(btc);
    address _spToken = address(spToken);
    address _jpToken = address(jpToken);
    uint256 _autoLiquidateThreshold = 2 * 10**7;

    approve(address(spToken));
    spToken.addMinter(address(pools));

    approve(address(jpToken));
    jpToken.addMinter(address(pools));

    // ---------match-------------------------
    pools.createPoolInfo(
      _settleTime, 
      _endTime, 
      _interestRate, 
      _maxSupply, 
      _martgageRate, 
      _lendToken, 
      _borrowToken, 
      _spToken, 
      _jpToken, 
      _autoLiquidateThreshold);            
  }


  function test_normal_finish() public {
    console.log("================ test normal finish ================");
    uint256 _pid = 0;

    // pool state is 0 match
    assertEq(pools.getPoolState(_pid), 0);

    // alice deposit lend token(usdc)
    vm.startPrank(alice);
    usdc.approve(address(pools), 100000 ether);
    pools.depositLend(_pid, 10 ether);
    vm.stopPrank();

    // bob deposit borrow token (btc) 
    vm.startPrank(bob);
    btc.approve(address(pools), 100000 ether);
    pools.depositBorrow(_pid, 10 ether);
    vm.stopPrank();

    // emergency is only allowed when settle is not success
    vm.prank(alice);
    vm.expectRevert("state: state must be undone");
    pools.emergencyLendWithdrawal(_pid);

    // --------------settle -------------------------
    vm.expectRevert(unicode"settle: 小于结算时间");
    pools.settle(_pid);

    vm.warp(block.timestamp + 65);
    pools.settle(_pid);
    assertEq(pools.getPoolState(_pid), 1);

    // depisit is not allowed now
    vm.prank(alice);
    vm.expectRevert("Less than this time");
    pools.depositLend(_pid, 10 ether);

    // borrow is not allowed
    vm.prank(bob);
    vm.expectRevert("Less than this time");
    pools.depositBorrow(_pid, 10 ether);

    // claim lend
    vm.prank(alice);
    pools.claimLend(_pid);
    console.log("sp token of alice", spToken.balanceOf(alice) / 10**18);

    // claim borrow
    vm.prank(bob);
    pools.claimBorrow(_pid);
    console.log("jp token of bob", jpToken.balanceOf(bob)/ 10 ** 18);
    assertEq(usdc.balanceOf(bob), 5 ether);

    // mock liquidity
    (uint amountA, uint amountB, uint liquidity) = swapRouter.addLiquidity(
      address(btc), 
      address(usdc), 
      10000 ether, 
      10000 ether, 
      9000 ether, 
      9000 ether, 
      address(this), 
      block.timestamp + 120);
      console.log("addLiquidity amountA", amountA);
      console.log("addLiquidity amountB", amountB);
      console.log("addLiquidity liquidity", liquidity);
      // finish
      vm.warp(block.timestamp + 130);
      pools.finish(_pid);

      //alice refund
      vm.startPrank(alice);
      console.log("alice:");
      console.log("\tbefore refund:", usdc.balanceOf(alice));
      pools.refundLend(_pid);
      console.log("\tafter refund:", usdc.balanceOf(alice));

      // alice withdraw
      pools.withdrawLend(_pid, spToken.balanceOf(alice));
      console.log("\tafter withdraw:", usdc.balanceOf(alice));
      vm.stopPrank();

      // bob withdraw
      vm.startPrank(bob);
      pools.withdrawBorrow(_pid, jpToken.balanceOf(bob));
      console.log("bob");
      console.log("\tusdc", usdc.balanceOf(bob));
      console.log("\tbt", btc.balanceOf(bob));
      vm.stopPrank();
  }

  function test_liquidation() public {
    console.log("================ test liquidation ================");
    uint256 _pid = 0;

    // deposit lend
    vm.startPrank(alice);
    usdc.approve(address(pools), 100000 ether);
    pools.depositLend(_pid, 10 ether);
    vm.stopPrank();

    // deposit borrow
    vm.startPrank(bob);
    btc.approve(address(pools), 100000 ether);
    pools.depositBorrow(_pid, 10 ether);
    vm.stopPrank();

    // settle
    vm.warp(block.timestamp + 65);
    pools.settle(_pid);
    assertEq(pools.getPoolState(_pid), 1);

    assertEq(pools.checkoutLiquidate(_pid), false);
    oracle.setPrice(address(btc), 8 * 10**3); 
    assertEq(pools.checkoutLiquidate(_pid), false);
    oracle.setPrice(address(btc), 55 * 10**2); 
    assertEq(pools.checkoutLiquidate(_pid), true);

    // mock liquidity
    (uint amountA, uint amountB, uint liquidity) = swapRouter.addLiquidity(
      address(btc), 
      address(usdc), 
      1000 ether, 
      550  ether, 
      0 ether, 
      0 ether, 
      address(this), 
      block.timestamp + 120);
      console.log("addLiquidity amountA", amountA);
      console.log("addLiquidity amountB", amountB);
      console.log("addLiquidity liquidity", liquidity);

      // liquid
      pools.liquidate(_pid); 

      //alice refund
      vm.startPrank(alice);
      pools.claimLend(_pid);
      console.log("alice:");
      console.log("\tbefore refund:", usdc.balanceOf(alice));
      pools.refundLend(_pid);
      console.log("\tafter refund:", usdc.balanceOf(alice));

      // alice withdraw
      pools.withdrawLend(_pid, spToken.balanceOf(alice));
      console.log("\tafter withdraw:", usdc.balanceOf(alice));
      vm.stopPrank();

      // bob withdraw
      vm.startPrank(bob);
      pools.claimBorrow(_pid);
      pools.withdrawBorrow(_pid, jpToken.balanceOf(bob));
      console.log("bob");
      console.log("\tusdc", usdc.balanceOf(bob));
      console.log("\tbt", btc.balanceOf(bob));
      vm.stopPrank();
  }

  function approve(address addr) public {
    signs.createApplication(addr);
    bytes32 msgHash = signs.getApplicationHash(address(this), addr);
    vm.prank(alice);
    signs.signApplication(msgHash);
    vm.prank(bob);
    signs.signApplication(msgHash);
  }
}
