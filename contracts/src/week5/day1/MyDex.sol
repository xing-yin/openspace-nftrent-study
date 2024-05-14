// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { UniswapV2Library } from "./libraries/UniswapV2Library.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { Test, console } from "forge-std/Test.sol";

interface IDex {
  /**
   * @dev 卖出ETH，兑换成 buyToken
   *      msg.value 为出售的ETH数量
   * @param buyToken 兑换的目标代币地址
   * @param minBuyAmount 要求最低兑换到的 buyToken 数量
   */
  function sellETH(address buyToken, uint256 minBuyAmount) external payable;

  /**
   * @dev 买入ETH，用 sellToken 兑换
   * @param sellToken 出售的代币地址
   * @param sellAmount 出售的代币数量
   * @param minBuyAmount 要求最低兑换到的ETH数量
   */
  function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex {
  address public factory; // uniswap factory contract address
  address public WETH; // WETH contract address

  event SellETHSuccess(address indexed user, address indexed token, uint256 minBuyAmount);

  event BuyETHSuccess(address indexed user, address indexed sellToken, uint256 sellAmount, uint256 minBuyAmount);

  constructor(address factory_, address WETH_) {
    factory = factory_;
    WETH = WETH_;
  }

  /**
   * @dev 卖出ETH，兑换成 buyToken
   *      msg.value 为出售的ETH数量
   * @param buyToken 兑换的目标代币地址
   * @param minBuyAmount 要求最低兑换到的 buyToken 数量
   */
  function sellETH(address buyToken, uint256 minBuyAmount) public payable {
    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = buyToken;
    _swapExactETHForTokens(minBuyAmount, path, msg.sender);

    emit SellETHSuccess(msg.sender, buyToken, minBuyAmount);
  }

  /**
   * @dev 买入ETH，用 sellToken 兑换
   * @param sellToken 出售的代币地址
   * @param sellAmount 出售的代币数量
   * @param minBuyAmount 要求最低兑换到的ETH数量
   */
  function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) public {
    address[] memory path = new address[](2);
    path[0] = sellToken;
    path[1] = WETH;
    _swapExactTokensForETH(sellAmount, minBuyAmount, path, msg.sender);

    emit BuyETHSuccess(msg.sender, sellToken, sellAmount, minBuyAmount);
  }

  //================================
  //====== private function ========
  //================================
  function _swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to)
    public
    returns (uint256[] memory amounts)
  {
    //确认路径最后一个地址为WETH
    require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");
    //数额数组 ≈ 遍历路径数组((输入数额 * 997 * 储备量Out) / (储备量In * 1000 + 输入数额 * 997))
    amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    console.log("_swapExactTokensForETH amounts:", amounts[0]);
    //确认数额数组最后一个元素>=最小输出数额
    require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    //将数量为数额数组[0]的路径[0]的token从调用者账户发送到路径0,1的pair合约
    _safeTransferFrom(path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
    //私有交换(数额数组,路径数组,当前合约地址)
    _swap(amounts, path, address(this));
    //从WETH合约提款数额数组最后一个数值的ETH
    IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    //将数额数组最后一个数值的ETH发送到to地址
    _safeTransferETH(to, amounts[amounts.length - 1]);
  }

  function _swapExactETHForTokens(uint256 amountOutMin, address[] memory path, address to)
    public
    payable
    returns (uint256[] memory amounts)
  {
    //确认路径第一个地址为WETH
    require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");
    //数额数组 ≈ 遍历路径数组((msg.value * 997 * 储备量Out) / (储备量In * 1000 + msg.value * 997))
    amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
    console.log("_swapExactETHForTokens amounts:", amounts[0]);
    //确认数额数组最后一个元素>=最小输出数额
    require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    //将数额数组[0]的数额存款ETH到WETH合约
    IWETH(WETH).deposit{ value: amounts[0] }();
    //断言将数额数组[0]的数额的WETH发送到路径(0,1)的pair合约地址
    assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
    //私有交换(数额数组,路径数组,to地址)
    _swap(amounts, path, to);
  }

  function _swap(uint256[] memory amounts, address[] memory path, address _to) private {
    //遍历路径数组
    for (uint256 i; i < path.length - 1; i++) {
      //(输入地址,输出地址) = (当前地址,下一个地址)
      (address input, address output) = (path[i], path[i + 1]);
      //token0 = 排序(输入地址,输出地址)
      (address token0,) = UniswapV2Library.sortTokens(input, output);
      //输出数量 = 数额数组下一个数额
      uint256 amountOut = amounts[i + 1];
      //(输出数额0,输出数额1) = 输入地址==token0 ? (0,输出数额) : (输出数额,0)
      // 因为 swap 每一个交易对中只取一个输出金额，只需要一个输出金额做计算，另一个取 0
      (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
      //to地址 = i<路径长度-2 ? (输出地址,路径下下个地址)的pair合约地址 : to地址
      address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
      //调用(输入地址,输出地址)的pair合约地址的交换方法(输出数额0,输出数额1,to地址,0x00)
      IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
    }
  }

  function _safeTransferETH(address to, uint256 value) internal {
    // solium-disable-next-line
    (bool success,) = to.call{ value: value }(new bytes(0));
    require(success, "TransferHelper: ETH_TRANSFER_FAILED");
  }

  function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
    // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    // solium-disable-next-line
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
  }
}
