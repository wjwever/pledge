// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {multiSignature} from "../src/multiSignature/multiSignature.sol";
import {DebtToken} from "../src/pledge/DebtToken.sol";
import {console} from "forge-std/console.sol";
import {BscPledgeOracle}  from "../src/pledge/BscPledgeOracle.sol";
import {PledgePool} from "../src/pledge/PledgePool.sol";

contract CounterScript is Script {
  multiSignature public signs;
  DebtToken public token;
  BscPledgeOracle  public oracle;
  PledgePool public pool;

  function setUp() public {}

  function run() public {
    uint256 deployPrivateKey= vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployPrivateKey);

    // deploy multiSignature
    address[] memory owners = new address[](3);
    owners[0] = 0x66F5A01fe7612Ad4F77968EaCC07876A8E02784F;
    owners[1] = 0x47391418DdD8A0D1FaD18f39DbC8eDF5b661C7C9;
    owners[2] = 0x2067dfbd0011dB36A3212aacd2d6d00D0F278668;

    signs = new multiSignature(owners, 2);
    console.log("Address of multisignature:", address(signs));

    // deploy DebtToken
    token = new DebtToken("DebtToken", "DT", address(signs));
    console.log("Address of DebtToken:", address(token));

    // depoly oracle
    oracle = new BscPledgeOracle(address(signs));
    console.log("Address of oracle:", address(oracle));
    vm.stopBroadcast();

    // deploy swap router, use exists
    // 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
    address swapRouter = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    address feedAddr = makeAddr("feedAddr");
    
    // deploy pledge pool
    pool = new PledgePool(address(oracle), swapRouter, payable(feedAddr), address(signs));
    console.log("Address of pool:", address(pool));
  }
}
