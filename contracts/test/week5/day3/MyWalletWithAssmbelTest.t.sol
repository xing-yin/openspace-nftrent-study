pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { MyWallet } from "../../../src/week5/day3/MyWalletWithAssmbel.sol";

contract MyWalletWithAssmbelTest is Test {
  MyWallet public myWallet;
  address public owner = makeAddr("alice");

  function setUp() public {
    vm.startPrank(owner);
    myWallet = new MyWallet("MyWallet");
    vm.stopPrank();
  }

  // test transferOwernship
  function testTransferOwernship_succcess() public {
    vm.startPrank(owner);
    myWallet.transferOwernship(makeAddr("bob"));
    assertEq(myWallet.owner(), makeAddr("bob"));
    vm.stopPrank();
  }
}
