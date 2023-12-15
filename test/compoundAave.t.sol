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
import {AaveFlashLoan} from "../src/AAVE/AaveFlashLoan.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract compoundAave is Test {
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comp public comp;
    Comptroller public unitrollerProxy;
    WhitePaperInterestRateModel public whitePaperInterestRateModel;
    CErc20Delegate public cErc20Delegate;
    CErc20Delegator public cUSDC;
    CErc20Delegator public cUNI;
    SimplePriceOracle public simplePriceOracle;
    SimplePriceOracle public priceOracle;
    address public admin = makeAddr("admin");
    address public user1  = makeAddr("User1");
    address public user2  = makeAddr("User2");
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
   
    function setUp() public {

        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/d4TZEfJF1fOUpSaiaBFMOtiwMTa54gRb", 17465000);
        vm.startPrank(admin);

        //InterestRateModel
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(0,0);

        //PriceOracle
        priceOracle = new SimplePriceOracle();

        //Comptroller
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        //USDC
        cErc20Delegate = new CErc20Delegate();
        cUSDC = new CErc20Delegator(
            USDC,
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e6,
            "cUSDC",
            "cUSDC",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cUSDC)));

        //UNI
        cUNI = new CErc20Delegator(
            UNI,
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cUNI",
            "cUNI",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cUNI)));

        //在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)),1 * 1e30);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)),5 * 1e18);

        //設定 UNI 的 collateral factor 為 50%
        unitrollerProxy._setCollateralFactor(CToken(address(cUNI)),1e18 / 2);

        //Close factor 設定為 50%
        unitrollerProxy._setCloseFactor(1e18/2);
        //Liquidation incentive 設為 8% (1.08 * 1e18)
        unitrollerProxy._setLiquidationIncentive(1.08 * 1e18);

        //add tokenA Reserve for test 100 ether
        deal(USDC, admin, 1000000 * 10 ** 6);
        IERC20(USDC).approve(address(cUSDC), type(uint256).max);
        cUSDC._addReserves(2500 * 10 ** 6);
        vm.stopPrank();
    }

    //User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
    function test_case6_borrow() public {
        vm.startPrank(user1);

        deal(UNI, user1, 1000 ether);
        IERC20(UNI).approve(address(cUNI), type(uint256).max);
        cUNI.mint(1000 ether);

        //User1 使用 UNI 作為抵押品來借出 2500 顆 USDC
        address[] memory cTokenAddr = new address[](1);
        cTokenAddr[0] = address(cUNI);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cUSDC.borrow(2500 * 10 ** 6);
        assertEq(IERC20(USDC).balanceOf(user1), 2500 * 10 ** 6);
        vm.stopPrank();
    }
    //將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
    function test_case6_AAVA() public {
        //User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
        test_case6_borrow();
       
       //將 UNI 價格改為 $4 使 User1
        vm.startPrank(admin);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)),4 * 1e18);
        vm.stopPrank();
   
        vm.startPrank(user2);

        AaveFlashLoan aaveFlashLoan =new AaveFlashLoan(user2);
        //UNI抵押價值=1000顆*4U*0.5(CollateralFactor)=2000U
        //Close factor=50%，可清算2500 usdc * 0.5 = 1250 usdc
        address aavePool=0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
        uint256 aaveAmount = 1250  * 10 ** 6;
        address aaveAsset = USDC;
        uint cRepayAmount = 1250  * 10 ** 6;
        address cTokenCBorrow = address(cUSDC);
        address cTokenCollateral = address(cUNI);
        address underlyTokenCollateral = UNI;
        address borrower = user1;

        aaveFlashLoan.execute(aaveAmount ,cRepayAmount, aaveAsset, aavePool, cTokenCBorrow
        , cTokenCollateral, underlyTokenCollateral, borrower);
        
        //由合約提領
        aaveFlashLoan.withdraw(USDC);
        
        //約等於63 USDC
        assertEq( IERC20(USDC).balanceOf(user2), 63638693);
       
    }
    
}