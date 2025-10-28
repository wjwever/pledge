// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDC is ERC20, Ownable {
  constructor() ERC20("USDC", "USDC") Ownable(msg.sender) {
    _mint(msg.sender, 100000 * 10 ** 18);
  }
}
