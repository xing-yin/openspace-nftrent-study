// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";

// import {EsRnt} from "../src/EsRnt.sol";

// import {RntERC20} from "../src/RntERC20.sol";

// import {RntStake} from "../src/RntStake.sol";

import { RFTToken } from "../../../src/week4/day4/RFTToken.sol";
import { RenftIDO } from "../../../src/week4/day4/RFTIDO.sol";
import { RFTStake } from "../../../src/week4/day4/RFTStake.sol";
import { EsRNTToken } from "../../../src/week4/day4/EsRNTToken.sol";

contract RFTStakeTest is Test {
  EsRNTToken public esRnt;
  RFTToken public rnt;
  RFTStake public stake;

  address admin;
  address stakeUser1;
  address stakeUser2;

  // uint256 aaaPrivateKey;

  uint256 price = 1 * 1e17; // 0.1eth/个

  uint256 presaleDays = 2; // 预售时长

  function setUp() public {
    admin = makeAddr("admin");
    stakeUser1 = makeAddr("stakeUser1");
    stakeUser2 = makeAddr("stakeUser2");

    deal(admin, 100 ether);
    deal(stakeUser1, 101 ether);
    deal(stakeUser2, 102 ether);

    vm.startPrank(admin);
    rnt = new RFTToken();
    esRnt = new EsRNTToken();
    stake = new RFTStake(address(rnt), address(esRnt));

    rnt.chgAdmin(address(stake)); // 转移管理员给stake合约
    esRnt.chgAdmin(address(stake));

    rnt.transfer(stakeUser1, 100 * 1e18);

    console.log("[ADDRESS]admin:", address(admin));
    console.log("[ADDRESS]stakeUser1:", address(stakeUser1));
    console.log("[ADDRESS]stakeUser2:", address(stakeUser2));

    console.log("[ADDRESS]rnt:", address(rnt));
    console.log("[ADDRESS]esRnt:", address(esRnt));
    console.log("[ADDRESS]stake:", address(stake));
    vm.stopPrank();
  }

  function test_stake() public {
    vm.startPrank(stakeUser1);

    rnt.approve(address(stake), 5 * 1e18); // 质押前先授权
    uint256 t1 = block.timestamp;
    stake.stake(2 * 1e18);

    uint256 t2 = t1 + (1 days);
    vm.warp(t2);

    RFTStake.StkInfoForView memory stakeInfo = stake.queryStakeInfo(stakeUser1);

    // 质押2个，1天后，获得奖励应该2个esRnt
    assertEq(stakeInfo.esRntReward, 2 * 1e18);

    console.log("amount:", stakeInfo.amount);
    console.log("esRntReward:", stakeInfo.esRntReward);

    // 再追加质押3个，并继续保持2天
    stake.stake(3 * 1e18);
    uint256 t3 = t2 + (2 days);
    vm.warp(t3);

    stakeInfo = stake.queryStakeInfo(stakeUser1);

    // 获得奖励应该 2个*3天 + 3个*1天
    assertEq(stakeInfo.esRntReward, 2 * 1e18 * 3 + 3 * 1e18 * 2);

    console.log("amount2:", stakeInfo.amount);
    console.log("esRntReward2:", stakeInfo.esRntReward);

    // ////
    // 领取奖励10天后，应该有三分之一解锁
    stake.claim();

    vm.warp(block.timestamp + 10 * 24 * 3600);
    RFTStake.LockInfoForView memory lock = stake.queryLockInfo(stakeUser1);
    console.log("lockedAmount", lock.lockedAmount);
    console.log("unlockAmount", lock.unlockAmount);
    console.log("burnAmount", lock.burnAmount);

    // 未全部解锁，正常兑换应该失败
    vm.expectRevert();
    stake.exchangeEsRnt(false);

    // 超过30天之后，正常兑换后，rnt 余额应该正常增加
    uint256 balance1 = rnt.balanceOf(stakeUser1);
    vm.warp(block.timestamp + 25 * 24 * 3600);

    lock = stake.queryLockInfo(stakeUser1);
    console.log("lockedAmount22", lock.lockedAmount);
    console.log("unlockAmount22", lock.unlockAmount);
    console.log("burnAmount22", lock.burnAmount);

    stake.exchangeEsRnt(false);

    uint256 balance2 = rnt.balanceOf(stakeUser1);

    console.log("balance2 - balance1 =", balance2 - balance1);

    assertEq(balance2 - balance1, lock.unlockAmount);

    lock = stake.queryLockInfo(stakeUser1);

    console.log("lockedAmount33", lock.lockedAmount);
    console.log("unlockAmount33", lock.unlockAmount);
    console.log("burnAmount33", lock.burnAmount);
  }
}
