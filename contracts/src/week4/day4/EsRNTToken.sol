// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract EsRNTToken is ERC20Permit("esRNT") {
  address public admin;

  constructor() ERC20("esRNT", "esRNT") {
    // _update(address(0), msg.sender, _t_supply * 1e18);
    admin = msg.sender;
  }

  function mint(address _to, uint256 amount) external {
    require(msg.sender == admin, "only admin!");
    _update(address(0), _to, amount);
  }

  function chgAdmin(address na) external {
    require(msg.sender == admin, "only admin!");
    admin = na;
  }

  function _update(address from, address to, uint256 value) internal override {
    require(from == address(0), "esRNT can't transfer!");

    super._update(from, to, value);
  }
}
