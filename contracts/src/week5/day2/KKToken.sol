// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KK Token
 */
contract KKToken is Ownable, ERC20 {
  constructor(address initialOwner) Ownable(initialOwner) ERC20("KKToken", "KT") { }

  function mint(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
  }
}
