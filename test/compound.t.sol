// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Comp} from "../src/Governance/Comp.sol";
import {Comptroller} from "../src/Comptroller.sol";
import {Unitroller} from "../src/Unitroller.sol";
import {CErc20} from "../src/CErc20.sol";
import {CToken} from "../src/CToken.sol";
import {CErc20Delegate} from "../src/CErc20Delegate.sol";
import {CErc20Delegator} from "../src/CErc20Delegator.sol";
import {WhitePaperInterestRateModel} from "../src/WhitePaperInterestRateModel.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract CounterTest is Test {
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comp public comp;
    Comptroller public unitrollerProxy;
    WhitePaperInterestRateModel public whitePaperInterestRateModel;
    ERC20 public token;
    ERC20 public tokenA;
    ERC20 public tokenB;
    CErc20Delegate public cErc20Delegate;
    CErc20Delegator public cErc20Delegator;
    CErc20Delegator public cErc20DelegatorA;
    CErc20Delegator public cErc20DelegatorB;
    SimplePriceOracle public simplePriceOracle;
    SimplePriceOracle public priceOracle;
    address public admin = makeAddr("admin");
    address public user1  = makeAddr("User1 ");
    address public user2  = makeAddr("User2 ");
   
    function setUp() public {
        vm.startPrank(admin);

        //InterestRateModel
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(0,0);

        //PriceOracle
        priceOracle = new SimplePriceOracle();

        //comp token
        comp = new Comp(admin);

        //Comptroller
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);
    }

    //CASE2 for mint redeem
    function test_case2_mint_redeem() public {
        vm.startPrank(admin);
        //token
        token =new erc20Token("artToken","art");
        cErc20Delegate = new CErc20Delegate();

        cErc20Delegator = new CErc20Delegator(
            address(token),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cArt",
            "cArt",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        priceOracle.setUnderlyingPrice(CToken(address(cErc20Delegator)),1e18);
        unitrollerProxy._supportMarket(CToken(address(cErc20Delegator)));

        vm.startPrank(user1);
        uint256 tokenNumber = 100 * 10**18;
        deal(address(token), user1, tokenNumber);
        token.approve(address(cErc20Delegator), tokenNumber);
        assertEq(token.balanceOf(user1), tokenNumber);
        
        cErc20Delegator.mint(tokenNumber);
        assertEq(token.balanceOf(user1), 0);
        assertEq(cErc20Delegator.balanceOf(user1), tokenNumber);
        
        cErc20Delegator.redeem(tokenNumber);
        assertEq(cErc20Delegator.balanceOf(user1), 0);
        assertEq(token.balanceOf(user1), tokenNumber);
    }

    //CASE2 for borrow redrepayBorroweem
    function test_case2_borrow_repayBorrow() public {
        vm.startPrank(admin);
         //token
        token =new erc20Token("artToken","art");
        cErc20Delegate = new CErc20Delegate();

        cErc20Delegator = new CErc20Delegator(
            address(token),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cArt",
            "cArt",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        
        priceOracle.setUnderlyingPrice(CToken(address(cErc20Delegator)),1e18);
        unitrollerProxy._supportMarket(CToken(address(cErc20Delegator)));
        //collateral factor=90%
        unitrollerProxy._setCollateralFactor(CToken(address(cErc20Delegator)),1e17);

        vm.startPrank(user1);
        uint256 tokenNumber = 100 * 10**18;
        deal(address(token), user1, tokenNumber);
        token.approve(address(cErc20Delegator), type(uint256).max);

        //only can borrow 90% collateral
        cErc20Delegator.mint(tokenNumber);
        vm.expectRevert();
        cErc20Delegator.borrow(tokenNumber);
        cErc20Delegator.borrow(tokenNumber/10);
        cErc20Delegator.repayBorrow(tokenNumber/10);
    }

    //CASE3 tokenA tokenB borrow/repay
    function test_case3_borrow_repayBorrow() public {
        vm.startPrank(admin);
        //部署第二份 cERC20 合約，以下稱它們的 underlying tokens 為 token A 與 token B。
        tokenA =new erc20Token("tokenA","tokenA");
        cErc20Delegate = new CErc20Delegate();
        cErc20DelegatorA = new CErc20Delegator(
            address(tokenA),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cTokenA",
            "cTokenA",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cErc20DelegatorA)));
        //add tokenA Reserve for test 100 ether
        deal(address(tokenA), admin, 100 ether);
        tokenA.approve(address(cErc20DelegatorA), type(uint256).max);
        cErc20DelegatorA._addReserves(100 ether);

        tokenB = new erc20Token("tokenB","tokenB");
        cErc20DelegatorB = new CErc20Delegator(
            address(tokenB),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cTokenB",
            "cTokenB",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cErc20DelegatorB)));

        //在 Oracle 中設定一顆 token A 的價格為 $1，一顆 token B 的價格為 $100
        priceOracle.setUnderlyingPrice(CToken(address(cErc20DelegatorA)),1 * 1e18);
        priceOracle.setUnderlyingPrice(CToken(address(cErc20DelegatorB)),100 * 1e18);

        //Token B 的 collateral factor 為 50%
        unitrollerProxy._setCollateralFactor(CToken(address(cErc20DelegatorB)),1e18 / 2);

        //User1 使用 1 顆 token B 來 mint cToken
        vm.startPrank(user1);
        deal(address(tokenB), user1, 1 ether);
        tokenB.approve(address(cErc20DelegatorB), type(uint256).max);
        cErc20DelegatorB.mint(1 ether);

        //User1 使用 token B 作為抵押品來借出 50 顆 token A
        address[] memory cTokenAddr = new address[](1);
        cTokenAddr[0] = address(cErc20DelegatorB);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cErc20DelegatorA.borrow(50 ether);

        assertEq(tokenA.balanceOf(user1), 50 ether);
    }

    //CASE4 tokenA tokenB liquidateBorrow collateralFactor
    function test_case4_liquidateBorrow_collateralFactor() public {
        //延續 (3.) 的借貸場景
        test_case3_borrow_repayBorrow();

        //調整 token B 的 collateral factor，讓 User1 被 User2 清算
        //調整 token B 的 collateral factor 25%
        vm.startPrank(admin);
        unitrollerProxy._setCollateralFactor(CToken(address(cErc20DelegatorB)),1e18 / 4);
        unitrollerProxy._setCloseFactor(1e18/2);
        unitrollerProxy._setLiquidationIncentive(1.1 * 1e18);
        //因為可清算比率CloseFactor為50%，所以只能清算25顆TokenA
        vm.startPrank(user2);
        deal(address(tokenA), user2, 100 ether);
        tokenA.approve(address(cErc20DelegatorA), type(uint256).max);
        //超過25 Revert
        vm.expectRevert();
        cErc20DelegatorA.liquidateBorrow(user1, 26 ether, cErc20DelegatorB);
        //計算可清算數量=(25顆 TokenA)
        (,,uint borrowBalance) = unitrollerProxy.getAccountLiquidity(user1);
        assertEq(borrowBalance, 25 ether);
        cErc20DelegatorA.liquidateBorrow(user1, borrowBalance , cErc20DelegatorB);

        //比原始付出去25u還大所以有賺錢
        require(cErc20DelegatorB.balanceOf(user2)*100 > 25 ether);
    }

    //CASE4 tokenA tokenB liquidateBorrow
    //延續 (3.) 的借貸場景，調整 oracle 中 token B 的價格，讓 User1 被 User2 清算
    function test_case5_liquidateBorrow_oraclePrice() public {
        //延續 (3.) 的借貸場景
        test_case3_borrow_repayBorrow();

        //調整 oracle 中 token B 的價格，讓 User1 被 User2 清算
        vm.startPrank(admin);
        unitrollerProxy._setCloseFactor(1e18/2);
        unitrollerProxy._setLiquidationIncentive(1.1 * 1e18);

        //價格由100下降到80，抵押可借用的資產變成40(TokenB)
        //但是借出50價值的TokenA
        //所以可以清算10價值的TokenA
        priceOracle.setUnderlyingPrice(CToken(address(cErc20DelegatorB)),50 * 1e18);

        //因為可清算比率CloseFactor為50%，所以只能清算25顆TokenA
        vm.startPrank(user2);
        deal(address(tokenA), user2, 100 ether);
        tokenA.approve(address(cErc20DelegatorA), type(uint256).max);
         (,,uint borrowBalance) = unitrollerProxy.getAccountLiquidity(user1);
        cErc20DelegatorA.liquidateBorrow(user1, borrowBalance , cErc20DelegatorB);
        //比原始付出去25u還大所以有賺錢
       require(cErc20DelegatorB.balanceOf(user2)*80 > 25 ether);
    }
}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}