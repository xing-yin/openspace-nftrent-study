pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { RFTToken } from "../../../src/day4/RFTToken.sol";
import { WETH9 } from "../../../src/week5/day1/WETH.sol";
import { UniswapV2Factory } from "../../../src/week5/day1/UniswapV2Factory.sol";
import { UniswapV2Router01 } from "../../../src/week5/day1/online.sol";
import { UniswapV2Pair } from "../../../src/week5/day1/UniswapV2Pair.sol";
import { IUniswapV2Pair } from "../../../src/week5/day1/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Test is Test {
  UniswapV2Factory uniswapV2factory;
  UniswapV2Router01 uniswapV2Router;

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
    vm.stopPrank();

    vm.startPrank(swaper);
    // init some weth to swaper
    wethToken.deposit{ value: 120 ether }();
    vm.stopPrank();
  }

  // test createPair
  function testCreatePair_success() public {
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    console.log("pair is:", pair);
    assertTrue(pair != address(0), "pair should not be 0");
    assertEq(uniswapV2factory.allPairs(0), pair);
  }

  function testCreatePair_failed_when_two_token_is_same() public {
    vm.expectRevert("UniswapV2: IDENTICAL_ADDRESSES");
    uniswapV2factory.createPair(address(wethToken), address(wethToken));
  }

  // test addLiquidity
  function testAddLiquidity_success() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    console.log("pair is:", pair);
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 1000 ether);
    (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 1000, 2000, 900, 1800, pair, block.timestamp + 2000
    );
    assertEq(wethToken.balanceOf(pair), 1000);
    assertEq(rftToken.balanceOf(pair), 2000);
    assertTrue(amountA > 0);
    assertTrue(amountB > 0);
    assertTrue(liquidity > 0);
    vm.stopPrank();
  }

  function testAddLiquidity_failed_when_deadline_is_expired() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    console.log("pair is:", pair);
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 1000 ether);
    vm.expectRevert("UniswapV2Router: EXPIRED");
    uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 1000, 2000, 900, 1800, pair, block.timestamp - 1
    );
    vm.stopPrank();
  }

  // test removeLiquidity
  function testRemoveLiquidity_success() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 1000 ether);

    (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 1000, 2000, 900, 1800, deployer, block.timestamp + 2000
    );
    console.log("liquidity is:", liquidity);

    IUniswapV2Pair(pair).approve(address(uniswapV2Router), type(uint256).max);
    (uint256 amountARemoved, uint256 amountBRemoved) = uniswapV2Router.removeLiquidity(
      address(wethToken), address(rftToken), liquidity, 292, 200, deployer, block.timestamp + 2000
    );
    console.log("amountARemoved:", amountARemoved);
    console.log("amountBRemoved:", amountBRemoved);
    assertTrue(amountARemoved > 0);
    assertTrue(amountBRemoved > 0);
    vm.stopPrank();
  }

  function testRemoveLiquidity_success_when_exceed_amount() public {
    vm.startPrank(deployer);
    // pair address
    address pair = uniswapV2factory.createPair(address(wethToken), address(rftToken));
    wethToken.approve(address(uniswapV2Router), 1000 ether);
    rftToken.approve(address(uniswapV2Router), 1000 ether);

    (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
      address(wethToken), address(rftToken), 1000, 2000, 900, 1800, deployer, block.timestamp + 2000
    );
    console.log("liquidity is:", liquidity);

    IUniswapV2Pair(pair).approve(address(uniswapV2Router), type(uint256).max);
    vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
    (uint256 amountARemoved, uint256 amountBRemoved) = uniswapV2Router.removeLiquidity(
      // set a big amountAMin and amountBMin,cause INSUFFICIENT AMOUNT
      address(wethToken),
      address(rftToken),
      liquidity,
      1100,
      2100,
      deployer,
      block.timestamp + 2000
    );
    vm.stopPrank();
  }

  // test swapExactTokensForETH
  function testSwapExactTokensForETH_success() public {
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
    rftToken.approve(address(uniswapV2Router), 2000 ether);
    address[] memory path = new address[](2);
    path[0] = address(rftToken);
    path[1] = address(wethToken);
    (uint256[] memory amounts) =
      uniswapV2Router.swapExactTokensForETH(amountInRNTToken, amountOutMinWETH, path, swaper, block.timestamp + 2000);
    assertTrue(amounts[0] > 0); // check swap eth amount > 0
    vm.stopPrank();
  }

  function testSwapExactTokensForETH_failed_when_INSUFFICIENT_OUTPUT_AMOUNT() public {
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
    uint256 amountOutMinWETH = 51 ether; // set a impposible amount
    rftToken.approve(address(uniswapV2Router), 2000 ether);
    address[] memory path = new address[](2);
    path[0] = address(rftToken);
    path[1] = address(wethToken);
    vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    (uint256[] memory amounts) =
      uniswapV2Router.swapExactTokensForETH(amountInRNTToken, amountOutMinWETH, path, swaper, block.timestamp + 2000);

    vm.stopPrank();
  }

  // test swapExactETHForTokens
  function testSwapExactETHForTokens_success() public {
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
    uint256 amountOutMinRFTToken = 60 ether;
    address[] memory path = new address[](2);
    path[0] = address(wethToken);
    path[1] = address(rftToken);
    (uint256[] memory amounts) = uniswapV2Router.swapExactETHForTokens{ value: 50 ether }(
      amountOutMinRFTToken, path, swaper, block.timestamp + 2000
    );
    assertTrue(amounts[0] > 0); // check swap rft token amount > 0
    vm.stopPrank();
  }

  function testSwapExactETHForTokens_failed_when_Not_ETH() public {
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
    uint256 amountOutMinRFTToken = 100 ether; // set a impposible amountOutMinRFTToken
    address[] memory path = new address[](2);
    path[0] = address(rftToken);
    path[1] = address(rftToken);
    vm.expectRevert("UniswapV2Router: INVALID_PATH");
    (uint256[] memory amounts) = uniswapV2Router.swapExactETHForTokens{ value: 50 ether }(
      amountOutMinRFTToken, path, swaper, block.timestamp + 2000
    );
    vm.stopPrank();
  }

  function testSwapExactETHForTokens_failed_when_INSUFFICIENT_OUTPUT_AMOUNT() public {
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
    uint256 amountOutMinRFTToken = 100 ether; // set a impposible amountOutMinRFTToken
    address[] memory path = new address[](2);
    path[0] = address(wethToken);
    path[1] = address(rftToken);
    vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    (uint256[] memory amounts) = uniswapV2Router.swapExactETHForTokens{ value: 50 ether }(
      amountOutMinRFTToken, path, swaper, block.timestamp + 2000
    );
    vm.stopPrank();
  }
}
