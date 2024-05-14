// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract RFTToken is ERC20Permit {
  address public admin;

  constructor() ERC20Permit("RenftToken") ERC20("RenftToken", "RNT") {
    admin = msg.sender;
    _update(address(0), msg.sender, 21_000_000 * 1e18);
  }

  function mint(address _to, uint256 amount) external {
    require(msg.sender == admin, "only admin!");
    _update(address(0), _to, amount);
  }

  function chgAdmin(address na) external {
    require(msg.sender == admin, "only admin!");
    admin = na;
  }
}
