// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 编写 StakingPool 合约，实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚钱 KK Token。
//其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。
contract StakingPool {
  //==============================================================================
  //========================= Event ==============================================
  //==============================================================================
  event UserStaked(address indexed user, uint256 amount);
  event UserUnStake(address indexed user, uint256 amount);
  event UserRewardUpdated(address indexed user, uint256 lastAccumulatedRewardsPerToken, uint256 lastBlockNumber);
  event GlobalRewardsPerTokenUpdate(uint256 accumulatededRewardsPerToken, uint256 lastBlockNumber);
  event UserClaim(address indexed user, uint256 amount);

  //==============================================================================
  //========================= struct =============================================
  //==============================================================================
  // 全局奖励信息
  struct GlobalRewardsPerToken {
    uint256 accumulatededRewardsPerToken; // 累积每个 Token 的奖励数（此时的 token 为 ETH）
    uint256 lastBlockNumber; // 上次更新奖励的区块号
  }

  // 用户奖励信息
  struct UserReward {
    uint256 accumulateRewards; // 用户累计奖励
    uint256 lastAccumulatedRewardsPerToken; // 用户上次累积的每个 Token 的奖励数
    uint256 lastBlockNumber; // 用户上次更新奖励的区块号
  }

  uint256 public constant REWARD_KK_TOKEN_PER_BLOCK = 10; // 每一个区块产出 10 个 KK token
  uint256 public constant REWARD_PERCISION = 1e18; // 奖励的精度,防止过小

  uint256 public totalStakedAmount; // 总质押量（ETH）
  mapping(address => uint256) public userStake; // 用户质押的 ETH 数量

  ERC20 public immutable rewardsToken; // 奖励的 Token
  GlobalRewardsPerToken public globalRewardsPerToken; // 全局奖励信息
  mapping(address => UserReward) public accumulatedUserRewards; // 用户累计的奖励信息

  //==============================================================================
  //========================= constructor ========================================
  //==============================================================================
  constructor(address rewardsToken_) {
    rewardsToken = ERC20(rewardsToken_);
  }

  //==============================================================================
  //========================= public function ====================================
  //==============================================================================
  /**
   * @dev 质押 ETH 到合约
   */
  function stake() public payable {
    uint256 amount = msg.value;
    require(amount > 0, "ETH can not be zero");

    address user = msg.sender;
    // update rewards
    _updateRewards(user);
    totalStakedAmount += amount;
    userStake[user] += amount;
    emit UserStaked(user, amount);
  }

  /**
   * @dev 赎回质押的 ETH
   * @param amount 赎回数量
   */
  function unstake(uint256 amount) public {
    // check user stake amount gt amount
    address user = msg.sender;
    uint256 balanceAmount = userStake[user];
    require(balanceAmount >= amount, "StakingPool:insufficient_amount");

    // update rewards
    _updateRewards(user);
    totalStakedAmount -= amount;
    userStake[user] -= amount;

    // transfer ETH to user
    payable(user).transfer(amount);

    emit UserUnStake(user, amount);
  }

  /**
   * @dev 领取 KK Token 收益
   */
  function claim() public {
    _claim(msg.sender);
  }

  /**
   * @dev 获取质押的 ETH 数量
   * @param account 质押账户
   * @return 质押的 ETH 数量
   */
  function balanceOf(address account) public view returns (uint256) {
    return userStake[account];
  }

  /**
   * @dev 获取待领取的 KK Token 收益
   * @param account 质押账户
   * @return 待领取的 KK Token 收益
   */
  function earned(address account) public view returns (uint256) {
    UserReward memory userReward = accumulatedUserRewards[account];
    GlobalRewardsPerToken memory globalRewardsPerToken_ = _caculateGlobalRewardsPerToken(globalRewardsPerToken);
    return userReward.accumulateRewards
      + _calculateUserRewards(account, globalRewardsPerToken_.accumulatededRewardsPerToken, userReward.accumulateRewards);
  }

  //==============================================================================
  //========================= internal function ====================================
  //==============================================================================
  function _claim(address user) internal {
    // update rewards
    UserReward memory userReward = _updateRewards(user);
    uint256 rewards = userReward.accumulateRewards;

    accumulatedUserRewards[user].accumulateRewards = 0;

    // transfer kk token to user for rewards
    rewardsToken.transfer(user, rewards);

    emit UserClaim(user, rewards);
  }

  function _updateRewards(address user) internal returns (UserReward memory) {
    // update GlobalRewardsPerToken
    GlobalRewardsPerToken memory globalRewardsPerTokenNew = _updateGlobalRewardsPerToken();

    // update user rewards
    UserReward memory userReward = accumulatedUserRewards[user];
    if (globalRewardsPerTokenNew.lastBlockNumber == userReward.lastBlockNumber) {
      return userReward;
    }

    // calculate and update user new rewards
    userReward.accumulateRewards += _calculateUserRewards(
      user, userReward.lastAccumulatedRewardsPerToken, globalRewardsPerTokenNew.accumulatededRewardsPerToken
    );
    userReward.lastAccumulatedRewardsPerToken = globalRewardsPerTokenNew.accumulatededRewardsPerToken;
    userReward.lastBlockNumber = globalRewardsPerTokenNew.lastBlockNumber;
    accumulatedUserRewards[user] = userReward;

    emit UserRewardUpdated(user, userReward.lastAccumulatedRewardsPerToken, userReward.lastBlockNumber);

    return userReward;
  }

  function _calculateUserRewards(
    address user,
    uint256 currentAccumulatedRewardsPerToken,
    uint256 accumulatededRewardsPerToken
  ) internal view returns (uint256) {
    return userStake[user] * (currentAccumulatedRewardsPerToken - accumulatededRewardsPerToken) / REWARD_PERCISION;
  }

  function _updateGlobalRewardsPerToken() internal returns (GlobalRewardsPerToken memory) {
    GlobalRewardsPerToken memory globalRewardsPerTokenIn = globalRewardsPerToken;
    GlobalRewardsPerToken memory globalRewardsPerTokenOut = _caculateGlobalRewardsPerToken(globalRewardsPerTokenIn);

    globalRewardsPerToken = globalRewardsPerTokenOut;

    emit GlobalRewardsPerTokenUpdate(
      globalRewardsPerTokenOut.accumulatededRewardsPerToken, globalRewardsPerTokenOut.lastBlockNumber
    );
    return globalRewardsPerTokenOut;
  }

  function _caculateGlobalRewardsPerToken(GlobalRewardsPerToken memory globalRewardsPerTokenIn)
    internal
    view
    returns (GlobalRewardsPerToken memory)
  {
    GlobalRewardsPerToken memory globalRewardsPerTokenOut = GlobalRewardsPerToken(
      globalRewardsPerTokenIn.accumulatededRewardsPerToken, globalRewardsPerTokenIn.lastBlockNumber
    );

    // if block number no change ,skip
    uint256 currentBlockNumber = block.number;
    if (currentBlockNumber == globalRewardsPerTokenOut.lastBlockNumber) {
      return globalRewardsPerTokenOut;
    }

    // if totalStakedAmount is zero, skip
    if (totalStakedAmount == 0) {
      return globalRewardsPerTokenOut;
    }

    // calculte and update current accumulatededRewardsPerToken
    globalRewardsPerTokenOut.accumulatededRewardsPerToken += REWARD_PERCISION * REWARD_KK_TOKEN_PER_BLOCK
      * (currentBlockNumber - globalRewardsPerTokenOut.lastBlockNumber) / totalStakedAmount; // 为了确保精度，先乘以 1e18

    // update curent blockNumber
    globalRewardsPerTokenOut.lastBlockNumber = currentBlockNumber;

    // return
    return globalRewardsPerTokenOut;
  }
}
