pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { RFTToken } from "../../../src/week4/day4/RFTToken.sol";
import { WETH9 } from "../../../src/week5/day1/WETH.sol";
import { UniswapV2Factory } from "../../../src/week5/day1/UniswapV2Factory.sol";
import { UniswapV2Router01 } from "../../../src/week5/day1/online.sol";
import { MyDex } from "../../../src/week5/day1/MyDex.sol";
import { UniswapV2Pair } from "../../../src/week5/day1/UniswapV2Pair.sol";
import { IUniswapV2Pair } from "../../../src/week5/day1/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Test is Test {
  UniswapV2Factory uniswapV2factory;
  UniswapV2Router01 uniswapV2Router;
  MyDex myDex;

  WETH9 wethToken;
  RFTToken rftToken;

  address public deployer = makeAddr("alice");
  address public swaper = makeAddr("bob");

  function setUp() public {
    vm.deal(deployer, 100 ether);
    vm.deal(swaper, 220 ether);

    vm.startPrank(deployer);
    wethToken = new WETH9();
    rftToken = new RFTToken();

    // init some weth to deployer
    wethToken.deposit{ value: 100 ether }();
    // init some rft token to swaper
    rftToken.transfer(swaper, 150 ether);

    uniswapV2factory = new UniswapV2Factory(deployer);
    uniswapV2Router = new UniswapV2Router01(address(uniswapV2factory), address(wethToken));

    myDex = new MyDex(address(uniswapV2factory), address(wethToken));
    vm.stopPrank();

    vm.startPrank(swaper);
    // init some weth to swaper
    wethToken.deposit{ value: 120 ether }();
    vm.stopPrank();
  }

  // test swapExactTokensForETH
  function testBuyETH_success() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 2000 ether);

    (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 100 ether, 200 ether, 90, 180, deployer, block.timestamp + 2000
    );
    console.log("liquidity is:", liquidity);
    vm.stopPrank();

    vm.startPrank(swaper);
    uint256 amountInRNTToken = 100 ether;
    uint256 amountOutMinWETH = 30 ether;
    rftToken.approve(address(myDex), 2000 ether);
    myDex.buyETH(address(rftToken), amountInRNTToken, amountOutMinWETH);
    vm.stopPrank();
  }


  // test swapExactETHForTokens
  function testSellETH_success() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 2000 ether);

    (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 100 ether, 200 ether, 90, 180, deployer, block.timestamp + 2000
    );
    console.log("liquidity is:", liquidity);
    vm.stopPrank();

    vm.startPrank(swaper);
    uint256 amountOutMinRFTToken = 30 ether;
    myDex.sellETH{value: 10 ether}(address(rftToken), amountOutMinRFTToken);
    vm.stopPrank();
  }

}
