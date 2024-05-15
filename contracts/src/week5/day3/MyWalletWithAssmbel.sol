// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MyWallet {
  string public name;
  mapping(address => bool) private approved;
  address public owner;

  modifier auth() {
    address currentOwner;
    assembly {
      currentOwner := sload(2) // Load the owner address from storage slot 2
    }
    require(msg.sender == owner, "Not authorized");
    _;
  }

  constructor(string memory _name) {
    name = _name;
    owner = msg.sender;
  }

  function transferOwernship(address _addr) public auth {
    require(_addr != address(0), "New owner is the zero address");

    address currentOwner;
    assembly {
      currentOwner := sload(2) // Load the owner address from storage slot 2
    }
    require(currentOwner != _addr, "New owner is the same as the old owner");

    assembly {
      sstore(2, _addr) // Store the new owner address to storage slot 2
    }
  }
}
