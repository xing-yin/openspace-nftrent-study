pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { StakingPool } from "../../../src/week5/day2/StakingPool.sol";
import { KKToken } from "../../../src/week5/day2/KKToken.sol";

contract StakingPoolTest is Test {
  StakingPool public stakingPool;
  KKToken public kkToken;

  address public kkTokenOwner = makeAddr("alice");
  address public stakerBob = makeAddr("bob");
  address public stakerCindy = makeAddr("cindy");

  function setUp() public {
    kkToken = new KKToken(kkTokenOwner);
    stakingPool = new StakingPool(address(kkToken));

    vm.startPrank(kkTokenOwner);
    kkToken.mint(address(stakingPool), 100 ether); // init some kktoken to stakingPool
    vm.stopPrank();

    // prepare some eth
    vm.deal(kkTokenOwner, 100 ether);
    vm.deal(stakerBob, 100 ether);
    vm.deal(stakerCindy, 100 ether);
  }

  // test stake
  function testStake_succcess() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 1 ether }();
    assertEq(stakingPool.userStake(stakerBob), 1 ether);
    assertEq(stakingPool.totalStakedAmount(), 1 ether);
    vm.stopPrank();
  }

  function testStake_fail_when_eth_is_zero() public {
    vm.startPrank(stakerBob);
    vm.expectRevert("ETH can not be zero");
    stakingPool.stake{ value: 0 ether }();
    vm.stopPrank();
  }

  // test unstake
  function testUnstake_succcess() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();

    vm.warp(10);
    stakingPool.unstake(8 ether);
    assertEq(stakingPool.userStake(stakerBob), 2 ether);
    assertEq(stakingPool.totalStakedAmount(), 2 ether);
    vm.stopPrank();
  }

  function testUnstake_failed_when_amount_exceed_user_balance() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();

    vm.warp(10);
    vm.expectRevert("StakingPool:insufficient_amount");
    stakingPool.unstake(100 ether);
    vm.stopPrank();
  }

  // test claim
  function testClaim_success() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();

    vm.roll(10); // set block numeber to 10
    stakingPool.claim();
    assertEq(kkToken.balanceOf(stakerBob), 100);
    vm.stopPrank();
  }

  function testClaim_success_with_two_staker() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();
    vm.stopPrank();

    vm.startPrank(stakerCindy);
    stakingPool.stake{ value: 10 ether }();
    vm.stopPrank();

    vm.startPrank(stakerBob);
    vm.roll(10); // set block numeber to 10
    stakingPool.claim();
    assertEq(kkToken.balanceOf(stakerBob), 55);
    vm.stopPrank();
  }

  function testClaim_success_with_two_staker_in_different_time_stake() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();
    vm.stopPrank();

    // in order to make stakerCindy's reward is 50
    vm.roll(5);
    vm.startPrank(stakerCindy);
    stakingPool.stake{ value: 10 ether }();
    vm.stopPrank();

    vm.roll(10); // set block numeber to 10
    vm.startPrank(stakerBob);
    stakingPool.claim();
    vm.stopPrank();

    vm.startPrank(stakerCindy);
    stakingPool.claim();
    vm.stopPrank();

    console.log("kkToken.balanceOf(stakerBob)", kkToken.balanceOf(stakerBob));
    console.log("kkToken.balanceOf(stakerCindy)", kkToken.balanceOf(stakerCindy));
    assertEq(kkToken.balanceOf(stakerBob), 75);
    assertEq(kkToken.balanceOf(stakerCindy), 25);
  }

  // test balanceOf
  function testBalanceOf() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();
    assertEq(stakingPool.balanceOf(stakerBob), 10 ether);
    vm.stopPrank();
  }

  // test earned
  function testEarned() public {
    vm.startPrank(stakerBob);
    stakingPool.stake{ value: 10 ether }();
    vm.roll(10); // set block numeber to 10
    assertEq(stakingPool.earned(stakerBob), 100);
    vm.stopPrank();
  }
}
